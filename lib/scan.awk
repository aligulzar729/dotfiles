# Reads a unified diff, reports secrets and PII on added lines.
# Called by lib/scan.sh. Kept as a real awk file so the patterns can contain
# quotes and apostrophes without shell escaping.
#
# Pass -v allow_file=<path> for .pii-allow.
# No {n} intervals in the patterns: the awk on macOS does not support them.

BEGIN {
  dq = "\""
  sq = "'"

  n = 0
  # strict = an "example.com" on the same line cannot silence it. Only a
  # "pii-ok" marker or a .pii-allow entry can. These formats are never
  # incidentally present in a line that merely mentions a fiction domain.
  name[++n] = "private key";    pat[n] = "BEGIN [A-Z ]*PRIVATE KEY"; strict[n] = 1
  name[++n] = "aws key";        pat[n] = "AKIA[0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z]+"; strict[n] = 1
  name[++n] = "github token";   pat[n] = "gh[pousr]_[A-Za-z0-9][A-Za-z0-9][A-Za-z0-9]+"; strict[n] = 1
  name[++n] = "anthropic key";  pat[n] = "sk-ant-[A-Za-z0-9_-]+"   # pii-ok
  # The boundary matters: without it "task-123" and "risk-register" match.
  name[++n] = "openai key";     pat[n] = "(^|[^A-Za-z0-9_])sk-[A-Za-z0-9_-][A-Za-z0-9_-][A-Za-z0-9_-]+"   # pii-ok
  name[++n] = "slack token";    pat[n] = "xox[baprs]-[A-Za-z0-9-]+"
  # eyJ is base64 for {", so a three-part eyJ.eyJ.sig is a JWT and little else.
  name[++n] = "jwt";            pat[n] = "eyJ[A-Za-z0-9_-]+\\.eyJ[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]+"; strict[n] = 1   # pii-ok
  name[++n] = "secret literal"; pat[n] = "(api[_-]?key|secret|passwd|password|token)[ \t]*[=:][ \t]*[\"'][^\"']+[\"']"
  name[++n] = "phone number";   pat[n] = "\\+[0-9]+[-. ][0-9]+[-. ][0-9]+[-. ][0-9]+"
  name[++n] = "email address";  pat[n] = "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z][a-zA-Z]+"
  npat = n

  # Soft: RFC 2606 and NANP fiction ranges. They silence ordinary patterns but
  # not the strict ones.
  ns = 0
  soft[++ns] = "example\\.(com|org|net)"
  soft[++ns] = "@example\\."
  soft[++ns] = "\\.example([^a-zA-Z]|$)"
  soft[++ns] = "555-?01[0-9][0-9]"
  soft[++ns] = "\\+1[-. ]?[0-9][0-9][0-9][-. ]?555[-. ]?[0-9]"
  nsoft = ns

  # Hard: a deliberate human decision, so it silences anything.
  nh = 0; np = 0
  hard[++nh] = "pii-ok"
  # Callable without an allowlist: getline on an empty filename is a fatal error.
  while (allow_file != "" && (getline line < allow_file) > 0) {
    if (line ~ /^[ \t]*(#|$)/) continue
    # "path:<regex>" exempts a whole file, so a deliberately tracked file does
    # not force its own contents to be copied into this list to silence them.
    if (line ~ /^path:/) { pathallow[++np] = substr(line, 6); continue }
    hard[++nh] = line
  }
  nhard = nh; npath = np

  quoted = "[" dq sq "][^" dq sq "]+[" dq sq "]"
  findings = 0
  file = "?"
  lineno = 0
}

# `git log -p` interleaves commits, so remember which one we are inside.
/^commit [0-9a-f][0-9a-f]/ { commit = substr($2, 1, 8); next }

/^\+\+\+ b\// {
  file = substr($0, 7)
  file_exempt = 0
  for (i = 1; i <= npath; i++)
    if (file ~ pathallow[i]) { file_exempt = 1; break }
  next
}

# @@ -old,count +new,count @@ - the new-side start line.
/^@@ / {
  split($3, a, ",")
  lineno = a[1] + 0
  if (lineno < 0) lineno = -lineno
  next
}

/^\+/ {
  if (file_exempt) { lineno++; next }

  content = substr($0, 2)
  for (i = 1; i <= nhard; i++)
    if (content ~ hard[i]) { lineno++; next }

  softened = 0
  for (i = 1; i <= nsoft; i++)
    if (content ~ soft[i]) { softened = 1; break }

  for (i = 1; i <= npat; i++) {
    if (content ~ pat[i]) {
      if (softened && !strict[i]) continue
      # Test fixtures look like assignments too. Real credentials are long and
      # not made of words. Match the value for THIS keyword: a UUID earlier on
      # the line would otherwise pass the length test for a short token after it.
      # Real keys are long; "sk-abc" in prose is not one.
      if (name[i] == "openai key") {
        if (!match(content, pat[i])) continue
        m = substr(content, RSTART, RLENGTH)
        sub(/^[^s]*/, "", m)
        if (length(m) < 24) continue
      }
      if (name[i] == "secret literal") {
        if (!match(content, pat[i])) continue
        assigned = substr(content, RSTART, RLENGTH)
        if (!match(assigned, quoted)) continue
        value = substr(assigned, RSTART + 1, RLENGTH - 2)
        if (length(value) < 20) continue
        if (value ~ /^[a-z]+(-[a-z]+)+$/) continue
      }
      excerpt = substr(content, 1, 40)
      # Never print the whole secret: this lands in scrollback and CI logs.
      if (length(excerpt) > 8) excerpt = substr(excerpt, 1, 8) "********"
      where = (commit == "") ? file ":" lineno : commit " " file ":" lineno
      printf "  %s  %s\n      %s\n", where, name[i], excerpt > "/dev/stderr"
      findings++
      break
    }
  }
  lineno++
}

END {
  if (findings > 0) {
    printf "\n  %d possible secret(s) or PII found\n\n", findings > "/dev/stderr"
    exit 1
  }
}
