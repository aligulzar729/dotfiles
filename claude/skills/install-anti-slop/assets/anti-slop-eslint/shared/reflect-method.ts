import { isGlobalReference } from "../compat.ts";

import type { ESTree, SourceCode } from "../compat.ts";

function isGlobalReflect(sourceCode: SourceCode, expression: ESTree.Expression): boolean {
  return (
    expression.type === "Identifier" &&
    expression.name === "Reflect" &&
    isGlobalReference(sourceCode, expression)
  );
}

/** Reports whether a call target names one method on the global Reflect object. */
export function isGlobalReflectMethodCall(
  sourceCode: SourceCode,
  callee: ESTree.Expression,
  methodName: string,
): boolean {
  if (!("property" in callee) || !("object" in callee) || !("computed" in callee)) return false;
  if (!isGlobalReflect(sourceCode, callee.object)) return false;
  const property = callee.property;
  return callee.computed
    ? property.type === "Literal" && property.value === methodName
    : property.type === "Identifier" && property.name === methodName;
}
