/**
   Function translations.
 */
module dpp.cursor.function_;

import dpp.from;

string[] translateFunction(in from!"clang".Cursor cursor,
                           ref from!"dpp.runtime.context".Context context)
    @safe
{
    import dpp.cursor.dlang: maybeRename, maybePragma;
    import dpp.cursor.aggregate: maybeRememberStructs;
    import dpp.type: translate;
    import clang: Cursor, Type, Language;
    import std.array: join, array;
    import std.conv: text;
    import std.algorithm: any, endsWith;
    import std.typecons: Yes;

    assert(
        cursor.kind == Cursor.Kind.FunctionDecl ||
        cursor.kind == Cursor.Kind.CXXMethod ||
        cursor.kind == Cursor.Kind.Constructor ||
        cursor.kind == Cursor.Kind.Destructor
    );


    // special case for the move constructor
    if(cursor.kind == Cursor.Kind.Constructor) {
        auto paramTypes = () @trusted {  return paramTypes(cursor).array; }();
        if(paramTypes.length == 1 && paramTypes[0].kind == Type.Kind.RValueReference) {
            context.log("*** type: ", paramTypes[0]);
            return [
                maybePragma(cursor, context) ~ " this(" ~ translate(paramTypes[0].pointee, context) ~ "*);",
                "this(" ~ translate(paramTypes[0], context) ~ " wrapper) {",
                "    this(&wrapper.value);",
                "}",
            ];
        }
    }

    const indentation = context.indentation;
    context.log("Function return type (raw):        ", cursor.type.returnType);

    const returnType = cursor.kind == Cursor.Kind.Constructor || cursor.kind == Cursor.Kind.Destructor
        ? ""
        : translate(cursor.returnType, context, Yes.translatingFunction);

    context.setIndentation(indentation);
    context.log("Function return type (translated): ", returnType);

    maybeRememberStructs(paramTypes(cursor), context);

    // Here we used to check that if there were no parameters and the language is C,
    // then the correct translation in D would be (...);
    // However, that's not allowed in D. It just so happens that C production code
    // exists that doesn't bother with (void), so instead of producing something that
    // doesn't compile, we compromise and assume the user meant (void)

    const paramTypes = translateParamTypes(cursor, context).array;
    const isVariadic = cursor.type.spelling.endsWith("...)");
    const variadicParams = isVariadic ? "..." : "";
    const allParams = paramTypes ~ variadicParams;

    const spelling = () {
        if(cursor.kind == Cursor.Kind.Constructor) return "this";
        if(cursor.kind == Cursor.Kind.Destructor) return "~this";
        return context.rememberLinkable(cursor);
    }();

    // const C++ method?
    const const_ = cursor.type.spelling.endsWith(") const") ? " const" : "";

    return [
        maybePragma(cursor, context) ~
        text(returnType, " ", spelling, "(", allParams.join(", "), ") @nogc nothrow", const_, ";")
    ];
}

auto translateParamTypes(in from!"clang".Cursor cursor,
                         ref from!"dpp.runtime.context".Context context)
    @safe
{
    import dpp.type: translate;
    import std.algorithm: map;
    import std.range: tee;
    import std.typecons: Yes;

    return paramTypes(cursor)
        .tee!((a){ context.log("Function Child: ", a); })
        .map!(a => translate(a, context, Yes.translatingFunction))
        ;
}

private auto paramTypes(in from!"clang".Cursor cursor)
    @safe
{
    import clang: Cursor;
    import std.algorithm: map, filter;

    return cursor
        .children
        .filter!(a => a.kind == Cursor.Kind.ParmDecl)
        .map!(a => a.type)
        ;
}
