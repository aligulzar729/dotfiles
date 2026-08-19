import type { JSONSchema4 } from "@typescript-eslint/utils/json-schema";
import type { TSESLint, TSESTree } from "@typescript-eslint/utils";

/**
 * Oxlint's `@oxlint/plugins` surface, expressed over the typescript-eslint AST.
 *
 * The rule sources in this directory stay line-for-line comparable with `src/`, so every
 * difference between the two linters is absorbed here instead of inside rule logic.
 */
export type SourceCode = TSESLint.SourceCode;
export type Scope = TSESLint.Scope.Scope;
export type Variable = TSESLint.Scope.Variable;

/** Rule options are plain JSON records here; no rule in this plugin takes an array option. */
export type OptionValue =
	| boolean
	| number
	| string
	| null
	| { readonly [key: string]: OptionValue | undefined };

export namespace ESTree {
	export type Node = TSESTree.Node;
	export type Program = TSESTree.Program;
	export type Statement = TSESTree.Statement;
	export type Expression = TSESTree.Expression;
	export type TSType = TSESTree.TypeNode;
	export type TSSignature = TSESTree.TypeElement;
	export type TSTypeAnnotation = TSESTree.TSTypeAnnotation;
	export type TSTypeReference = TSESTree.TSTypeReference;
	export type TSTypeLiteral = TSESTree.TSTypeLiteral;
	export type TSTypeAliasDeclaration = TSESTree.TSTypeAliasDeclaration;
	export type TSInterfaceDeclaration = TSESTree.TSInterfaceDeclaration;
	export type TSAsExpression = TSESTree.TSAsExpression;
	export type TSTypeAssertion = TSESTree.TSTypeAssertion;
	export type TSCallSignatureDeclaration = TSESTree.TSCallSignatureDeclaration;
	export type TSConstructSignatureDeclaration = TSESTree.TSConstructSignatureDeclaration;
	export type TSConstructorType = TSESTree.TSConstructorType;
	export type TSFunctionType = TSESTree.TSFunctionType;
	export type TSMethodSignature = TSESTree.TSMethodSignature;
	export type ArrowFunctionExpression = TSESTree.ArrowFunctionExpression;
	export type VariableDeclarator = TSESTree.VariableDeclarator;
	export type PropertyKey = TSESTree.PropertyName;
	export type SpreadElement = TSESTree.SpreadElement;

	/** Oxlint models declared and expression functions under one `Function` type. */
	export type Function =
		| TSESTree.FunctionDeclaration
		| TSESTree.FunctionExpression
		| TSESTree.TSDeclareFunction
		| TSESTree.TSEmptyBodyFunctionExpression;

	/** Oxlint separates binding identifiers from reads; typescript-eslint uses one node. */
	export type IdentifierReference = TSESTree.Identifier;

	export type ParamPattern = TSESTree.Parameter | TSESTree.DestructuringPattern;
}

/** Resolve one identifier to its declaring variable, or null when nothing declares it. */
export function resolveVariable(
	sourceCode: SourceCode,
	identifier: TSESTree.Identifier,
): Variable | null {
	let scope: Scope | null = sourceCode.getScope(identifier);
	while (scope !== null) {
		const variable = scope.set.get(identifier.name);
		if (variable !== undefined) return variable;
		scope = scope.upper;
	}
	return null;
}

/**
 * Report whether an identifier reads a global binding.
 *
 * Oxlint answers this with `sourceCode.isGlobalReference`, which ESLint exposes at runtime but
 * does not publish types for. Scope resolution answers the same question with typed APIs: a name
 * that resolves to nothing, or to a variable with no declaration, comes from the environment.
 */
export function isGlobalReference(
	sourceCode: SourceCode,
	identifier: TSESTree.Identifier,
): boolean {
	const variable = resolveVariable(sourceCode, identifier);
	return variable === null || variable.defs.length === 0;
}

type ReportDescriptor = {
	readonly node: ESTree.Node;
	readonly messageId: string;
	readonly data?: Readonly<Record<string, string>>;
};

export type RuleContext = {
	readonly sourceCode: SourceCode;
	readonly options: OptionValue[];
	readonly report: (descriptor: ReportDescriptor) => void;
};

type RuleMeta = {
	readonly type: "problem" | "suggestion" | "layout";
	readonly docs: { readonly description: string };
	readonly messages: Readonly<Record<string, string>>;
	readonly schema?: readonly JSONSchema4[];
	readonly defaultOptions?: OptionValue[];
};

type RuleDefinition = {
	readonly meta: RuleMeta;
	readonly createOnce: (context: RuleContext) => TSESLint.RuleListener;
};

export type Rule = TSESLint.RuleModule<string, OptionValue[]>;

/**
 * Translate one Oxlint rule definition into an ESLint rule.
 *
 * Oxlint builds a rule's visitor once and reuses it across files; ESLint builds one per file.
 * Rebuilding per file is the stricter of the two, so rules that reset state in `Program` keep
 * working unchanged.
 */
export function defineRule(definition: RuleDefinition): Rule {
	return {
		meta: { schema: [], ...definition.meta },
		defaultOptions: definition.meta.defaultOptions ?? [],
		create: (context) => definition.createOnce(context),
	};
}
