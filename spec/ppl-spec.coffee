TextEditor = null
buildTextEditor = (params) ->
  if atom.workspace.buildTextEditor?
    atom.workspace.buildTextEditor(params)
  else
    TextEditor ?= require('atom').TextEditor
    new TextEditor(params)

describe "Language-PPL", ->
  grammar = null

  beforeEach ->
    waitsForPromise ->
      atom.packages.activatePackage('language-ppl')

  describe "PPL", ->
    beforeEach ->
      grammar = atom.grammars.grammarForScopeName('source.ppl')

    it "parses the grammar", ->
      expect(grammar).toBeTruthy()
      expect(grammar.scopeName).toBe 'source.ppl'

    it "tokenizes functions", ->
      lines = grammar.tokenizeLines '''
        int something(int param) {
          return 0;
        }
      '''
      expect(lines[0][0]).toEqual value: 'int', scopes: ['source.ppl', 'storage.type.ppl']
      expect(lines[0][2]).toEqual value: 'something', scopes: ['source.ppl', 'meta.function.ppl', 'entity.name.function.ppl']
      expect(lines[0][3]).toEqual value: '(', scopes: ['source.ppl', 'meta.function.ppl', 'meta.parens.ppl', 'punctuation.section.parens.begin.ppl']
      expect(lines[0][4]).toEqual value: 'int', scopes: ['source.ppl', 'meta.function.ppl', 'meta.parens.ppl', 'storage.type.ppl']
      expect(lines[0][6]).toEqual value: ')', scopes: ['source.ppl', 'meta.function.ppl', 'meta.parens.ppl', 'punctuation.section.parens.end.ppl']
      expect(lines[0][8]).toEqual value: '{', scopes: ['source.ppl', 'meta.function.ppl', 'meta.block.ppl', 'punctuation.section.block.begin.ppl']
      expect(lines[1][1]).toEqual value: 'return', scopes: ['source.ppl', 'meta.function.ppl', 'meta.block.ppl', 'keyword.control.ppl']
      expect(lines[1][3]).toEqual value: '0', scopes: ['source.ppl', 'meta.function.ppl', 'meta.block.ppl', 'constant.numeric.ppl']
      expect(lines[2][0]).toEqual value: '}', scopes: ['source.ppl', 'meta.function.ppl', 'meta.block.ppl', 'punctuation.section.block.end.ppl']

    it "tokenizes various _t types", ->
      {tokens} = grammar.tokenizeLine 'size_t var;'
      expect(tokens[0]).toEqual value: 'size_t', scopes: ['source.ppl', 'support.type.sys-types.ppl']

      {tokens} = grammar.tokenizeLine 'pthread_t var;'
      expect(tokens[0]).toEqual value: 'pthread_t', scopes: ['source.ppl', 'support.type.pthread.ppl']

      {tokens} = grammar.tokenizeLine 'int32_t var;'
      expect(tokens[0]).toEqual value: 'int32_t', scopes: ['source.ppl', 'support.type.stdint.ppl']

      {tokens} = grammar.tokenizeLine 'myType_t var;'
      expect(tokens[0]).toEqual value: 'myType_t', scopes: ['source.ppl', 'support.type.posix-reserved.ppl']

    it "tokenizes 'line continuation' character", ->
      {tokens} = grammar.tokenizeLine 'ma' + '\\' + '\n' + 'in(){};'
      expect(tokens[0]).toEqual value: 'ma', scopes: ['source.ppl']
      expect(tokens[1]).toEqual value: '\\', scopes: ['source.ppl', 'constant.character.escape.line-continuation.ppl']
      expect(tokens[3]).toEqual value: 'in', scopes: ['source.ppl', 'meta.function.ppl', 'entity.name.function.ppl']

    describe "strings", ->
      it "tokenizes them", ->
        delimsByScope =
          'string.quoted.double.ppl': '"'
          'string.quoted.single.ppl': '\''

        for scope, delim of delimsByScope
          {tokens} = grammar.tokenizeLine delim + 'a' + delim
          expect(tokens[0]).toEqual value: delim, scopes: ['source.ppl', scope, 'punctuation.definition.string.begin.ppl']
          expect(tokens[1]).toEqual value: 'a', scopes: ['source.ppl', scope]
          expect(tokens[2]).toEqual value: delim, scopes: ['source.ppl', scope, 'punctuation.definition.string.end.ppl']

          {tokens} = grammar.tokenizeLine delim + 'a' + '\\' + '\n' + 'b' + delim
          expect(tokens[0]).toEqual value: delim, scopes: ['source.ppl', scope, 'punctuation.definition.string.begin.ppl']
          expect(tokens[1]).toEqual value: 'a', scopes: ['source.ppl', scope]
          expect(tokens[2]).toEqual value: '\\', scopes: ['source.ppl', scope, 'constant.character.escape.line-continuation.ppl']
          expect(tokens[4]).toEqual value: 'b', scopes: ['source.ppl', scope]
          expect(tokens[5]).toEqual value: delim, scopes: ['source.ppl', scope, 'punctuation.definition.string.end.ppl']

    describe "comments", ->
      it "tokenizes them", ->
        {tokens} = grammar.tokenizeLine '/**/'
        expect(tokens[0]).toEqual value: '/*', scopes: ['source.ppl', 'comment.block.ppl', 'punctuation.definition.comment.begin.ppl']
        expect(tokens[1]).toEqual value: '*/', scopes: ['source.ppl', 'comment.block.ppl', 'punctuation.definition.comment.end.ppl']

        {tokens} = grammar.tokenizeLine '/* foo */'
        expect(tokens[0]).toEqual value: '/*', scopes: ['source.ppl', 'comment.block.ppl', 'punctuation.definition.comment.begin.ppl']
        expect(tokens[1]).toEqual value: ' foo ', scopes: ['source.ppl', 'comment.block.ppl']
        expect(tokens[2]).toEqual value: '*/', scopes: ['source.ppl', 'comment.block.ppl', 'punctuation.definition.comment.end.ppl']

        {tokens} = grammar.tokenizeLine '*/*'
        expect(tokens[0]).toEqual value: '*/*', scopes: ['source.ppl', 'invalid.illegal.stray-comment-end.ppl']

    describe "preprocessor directives", ->
      it "tokenizes '#line'", ->
        {tokens} = grammar.tokenizeLine '#line 151 "copy.c"'
        expect(tokens[0]).toEqual value: '#', scopes: ['source.ppl', 'meta.preprocessor.ppl', 'keyword.control.directive.line.ppl', 'punctuation.definition.directive.ppl']
        expect(tokens[1]).toEqual value: 'line', scopes: ['source.ppl', 'meta.preprocessor.ppl', 'keyword.control.directive.line.ppl']
        expect(tokens[3]).toEqual value: '151', scopes: ['source.ppl', 'meta.preprocessor.ppl', 'constant.numeric.ppl']
        expect(tokens[5]).toEqual value: '"', scopes: ['source.ppl', 'meta.preprocessor.ppl', 'string.quoted.double.ppl', 'punctuation.definition.string.begin.ppl']
        expect(tokens[6]).toEqual value: 'copy.ppl', scopes: ['source.ppl', 'meta.preprocessor.ppl', 'string.quoted.double.ppl']
        expect(tokens[7]).toEqual value: '"', scopes: ['source.ppl', 'meta.preprocessor.ppl', 'string.quoted.double.ppl', 'punctuation.definition.string.end.ppl']

      it "tokenizes '#undef'", ->
        {tokens} = grammar.tokenizeLine '#undef FOO'
        expect(tokens[0]).toEqual value: '#', scopes: ['source.ppl', 'meta.preprocessor.ppl', 'keyword.control.directive.undef.ppl', 'punctuation.definition.directive.ppl']
        expect(tokens[1]).toEqual value: 'undef', scopes: ['source.ppl', 'meta.preprocessor.ppl', 'keyword.control.directive.undef.ppl']
        expect(tokens[2]).toEqual value: ' FOO', scopes: ['source.ppl', 'meta.preprocessor.ppl']

      it "tokenizes '#pragma'", ->
        {tokens} = grammar.tokenizeLine '#pragma once'
        expect(tokens[0]).toEqual value: '#', scopes: ['source.ppl', 'meta.preprocessor.ppl', 'keyword.control.directive.pragma.ppl', 'punctuation.definition.directive.ppl']
        expect(tokens[1]).toEqual value: 'pragma', scopes: ['source.ppl', 'meta.preprocessor.ppl', 'keyword.control.directive.pragma.ppl']
        expect(tokens[2]).toEqual value: ' once', scopes: ['source.ppl', 'meta.preprocessor.ppl']

        {tokens} = grammar.tokenizeLine '#pragma clang diagnostic push'
        expect(tokens[0]).toEqual value: '#', scopes: ['source.ppl', 'meta.preprocessor.ppl', 'keyword.control.directive.pragma.ppl', 'punctuation.definition.directive.ppl']
        expect(tokens[1]).toEqual value: 'pragma', scopes: ['source.ppl', 'meta.preprocessor.ppl', 'keyword.control.directive.pragma.ppl']
        expect(tokens[2]).toEqual value: ' clang diagnostic push', scopes: ['source.ppl', 'meta.preprocessor.ppl']

        {tokens} = grammar.tokenizeLine '#pragma mark – Initialization'
        expect(tokens[0]).toEqual value: '#', scopes: ['source.ppl', 'meta.section', 'meta.preprocessor.ppl', 'keyword.control.directive.pragma.pragma-mark.ppl',  'punctuation.definition.directive.ppl']
        expect(tokens[1]).toEqual value: 'pragma mark', scopes: ['source.ppl', 'meta.section',  'meta.preprocessor.ppl', 'keyword.control.directive.pragma.pragma-mark.ppl']
        expect(tokens[3]).toEqual value: '– Initialization', scopes: ['source.ppl', 'meta.section',  'meta.preprocessor.ppl', 'meta.toc-list.pragma-mark.ppl']

      describe "define", ->
        it "tokenizes '#define [identifier name]'", ->
          {tokens} = grammar.tokenizeLine '#define _FILE_NAME_H_'
          expect(tokens[0]).toEqual value: '#', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl', 'keyword.control.directive.define.ppl', 'punctuation.definition.directive.ppl']
          expect(tokens[1]).toEqual value: 'define', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl', 'keyword.control.directive.define.ppl']
          expect(tokens[3]).toEqual value: '_FILE_NAME_H_', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl', 'entity.name.function.preprocessor.ppl']

        it "tokenizes '#define [identifier name] [value]'", ->
          {tokens} = grammar.tokenizeLine '#define WIDTH 80'
          expect(tokens[0]).toEqual value: '#', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl', 'keyword.control.directive.define.ppl', 'punctuation.definition.directive.ppl']
          expect(tokens[1]).toEqual value: 'define', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl', 'keyword.control.directive.define.ppl']
          expect(tokens[3]).toEqual value: 'WIDTH', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl', 'entity.name.function.preprocessor.ppl']
          expect(tokens[5]).toEqual value: '80', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl', 'constant.numeric.ppl']

          {tokens} = grammar.tokenizeLine '#define ABC XYZ(1)'
          expect(tokens[0]).toEqual value: '#', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl', 'keyword.control.directive.define.ppl', 'punctuation.definition.directive.ppl']
          expect(tokens[1]).toEqual value: 'define', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl', 'keyword.control.directive.define.ppl']
          expect(tokens[3]).toEqual value: 'ABC', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl', 'entity.name.function.preprocessor.ppl']
          expect(tokens[4]).toEqual value: ' ', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl', 'meta.function.ppl', 'punctuation.whitespace.function.leading.ppl']
          expect(tokens[5]).toEqual value: 'XYZ', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl', 'meta.function.ppl', 'entity.name.function.ppl']
          expect(tokens[6]).toEqual value: '(', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl', 'meta.function.ppl', 'meta.parens.ppl', 'punctuation.section.parens.begin.ppl']
          expect(tokens[7]).toEqual value: '1', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl', 'meta.function.ppl', 'meta.parens.ppl', 'constant.numeric.ppl']
          expect(tokens[8]).toEqual value: ')', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl', 'meta.function.ppl', 'meta.parens.ppl', 'punctuation.section.parens.end.ppl']

          {tokens} = grammar.tokenizeLine '#define PI_PLUS_ONE (3.14 + 1)'
          expect(tokens[0]).toEqual value: '#', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl', 'keyword.control.directive.define.ppl', 'punctuation.definition.directive.ppl']
          expect(tokens[1]).toEqual value: 'define', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl', 'keyword.control.directive.define.ppl']
          expect(tokens[3]).toEqual value: 'PI_PLUS_ONE', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl', 'entity.name.function.preprocessor.ppl']
          expect(tokens[4]).toEqual value: ' (', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl']
          expect(tokens[5]).toEqual value: '3.14', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl', 'constant.numeric.ppl']
          expect(tokens[7]).toEqual value: '+', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl', 'keyword.operator.ppl']
          expect(tokens[9]).toEqual value: '1', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl', 'constant.numeric.ppl']
          expect(tokens[10]).toEqual value: ')', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl']

        describe "use", ->
          it "tokenizes '#use [RF] [Wav Ed file] [alias]'", ->
            {tokens} = grammar.tokenizeLine '#use RF1 "file" pf1'
            expect(tokens[0]).toEqual value: '#', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl', 'keyword.control.directive.use.ppl', 'punctuation.definition.directive.ppl']
            expect(tokens[1]).toEqual value: 'use', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl', 'keyword.control.directive.use.ppl']
            expect(tokens[3]).toEqual value: 'RF1', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl', 'entity.name.function.preprocessor.ppl']
            expect(tokens[5]).toEqual value: '"', scopes: ['source.ppl', 'meta.preprocessor.use.ppl', 'string.quoted.double.use.ppl', 'punctuation.definition.string.begin.ppl']
            expect(tokens[6]).toEqual value: 'file', scopes: ['source.ppl', 'meta.preprocessor.use.ppl', 'string.quoted.double.use.ppl']
            expect(tokens[7]).toEqual value: '"', scopes: ['source.ppl', 'meta.preprocessor.use.ppl', 'string.quoted.double.use.ppl', 'punctuation.definition.string.end.ppl']
            expect(tokens[9]).toEqual value: 'pf1', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl', 'keyword.control.directive.use.ppl']

        describe "macros", ->
          it "tokenizes them", ->
            {tokens} = grammar.tokenizeLine '#define INCREMENT(x) x++'
            expect(tokens[0]).toEqual value: '#', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl', 'keyword.control.directive.define.ppl', 'punctuation.definition.directive.ppl']
            expect(tokens[1]).toEqual value: 'define', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl', 'keyword.control.directive.define.ppl']
            expect(tokens[3]).toEqual value: 'INCREMENT', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl', 'entity.name.function.preprocessor.ppl']
            expect(tokens[4]).toEqual value: '(', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl', 'punctuation.definition.parameters.begin.ppl']
            expect(tokens[5]).toEqual value: 'x', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl', 'variable.parameter.preprocessor.ppl']
            expect(tokens[6]).toEqual value: ')', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl', 'punctuation.definition.parameters.end.ppl']
            expect(tokens[7]).toEqual value: ' x', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl']
            expect(tokens[8]).toEqual value: '++', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl', 'keyword.operator.increment.ppl']

            {tokens} = grammar.tokenizeLine '#define MULT(x, y) (x) * (y)'
            expect(tokens[0]).toEqual value: '#', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl', 'keyword.control.directive.define.ppl', 'punctuation.definition.directive.ppl']
            expect(tokens[1]).toEqual value: 'define', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl', 'keyword.control.directive.define.ppl']
            expect(tokens[3]).toEqual value: 'MULT', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl', 'entity.name.function.preprocessor.ppl']
            expect(tokens[4]).toEqual value: '(', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl', 'punctuation.definition.parameters.begin.ppl']
            expect(tokens[5]).toEqual value: 'x', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl', 'variable.parameter.preprocessor.ppl']
            expect(tokens[6]).toEqual value: ',', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl', 'variable.parameter.preprocessor.ppl', 'punctuation.separator.parameters.ppl']
            expect(tokens[7]).toEqual value: ' y', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl', 'variable.parameter.preprocessor.ppl']
            expect(tokens[8]).toEqual value: ')', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl', 'punctuation.definition.parameters.end.ppl']
            expect(tokens[9]).toEqual value: ' (x) ', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl']
            expect(tokens[10]).toEqual value: '*', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl', 'keyword.operator.ppl']
            expect(tokens[11]).toEqual value: ' (y)', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl']

            {tokens} = grammar.tokenizeLine '#define SWAP(a, b)  do { a ^= b; b ^= a; a ^= b; } while ( 0 )'
            expect(tokens[0]).toEqual value: '#', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl', 'keyword.control.directive.define.ppl', 'punctuation.definition.directive.ppl']
            expect(tokens[1]).toEqual value: 'define', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl', 'keyword.control.directive.define.ppl']
            expect(tokens[3]).toEqual value: 'SWAP', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl', 'entity.name.function.preprocessor.ppl']
            expect(tokens[4]).toEqual value: '(', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl', 'punctuation.definition.parameters.begin.ppl']
            expect(tokens[5]).toEqual value: 'a', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl', 'variable.parameter.preprocessor.ppl']
            expect(tokens[6]).toEqual value: ',', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl', 'variable.parameter.preprocessor.ppl', 'punctuation.separator.parameters.ppl']
            expect(tokens[7]).toEqual value: ' b', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl', 'variable.parameter.preprocessor.ppl']
            expect(tokens[8]).toEqual value: ')', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl', 'punctuation.definition.parameters.end.ppl']
            expect(tokens[10]).toEqual value: 'do', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl', 'keyword.control.ppl']
            expect(tokens[12]).toEqual value: '{', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl', 'meta.block.ppl', 'punctuation.section.block.begin.ppl']
            expect(tokens[13]).toEqual value: ' a ', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl', 'meta.block.ppl']
            expect(tokens[14]).toEqual value: '^=', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl', 'meta.block.ppl', 'keyword.operator.assignment.compound.bitwise.ppl']
            expect(tokens[15]).toEqual value: ' b; b ', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl', 'meta.block.ppl']
            expect(tokens[16]).toEqual value: '^=', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl', 'meta.block.ppl', 'keyword.operator.assignment.compound.bitwise.ppl']
            expect(tokens[17]).toEqual value: ' a; a ', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl', 'meta.block.ppl']
            expect(tokens[18]).toEqual value: '^=', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl', 'meta.block.ppl', 'keyword.operator.assignment.compound.bitwise.ppl']
            expect(tokens[19]).toEqual value: ' b; ', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl', 'meta.block.ppl']
            expect(tokens[20]).toEqual value: '}', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl', 'meta.block.ppl', 'punctuation.section.block.end.ppl']
            expect(tokens[22]).toEqual value: 'while', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl', 'keyword.control.ppl']
            expect(tokens[23]).toEqual value: ' ( ', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl']
            expect(tokens[24]).toEqual value: '0', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl', 'constant.numeric.ppl']
            expect(tokens[25]).toEqual value: ' )', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl']

          it "tokenizes multiline macros", ->
            lines = grammar.tokenizeLines '''
              #define max(a,b) (a>b)? \\
                                a:b
            '''
            expect(lines[0][14]).toEqual value: '\\', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl', 'constant.character.escape.line-continuation.ppl']

            lines = grammar.tokenizeLines '''
              #define SWAP(a, b)  { \\
                a ^= b; \\
                b ^= a; \\
                a ^= b; \\
              }
            '''
            expect(lines[0][0]).toEqual value: '#', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl', 'keyword.control.directive.define.ppl', 'punctuation.definition.directive.ppl']
            expect(lines[0][1]).toEqual value: 'define', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl', 'keyword.control.directive.define.ppl']
            expect(lines[0][3]).toEqual value: 'SWAP', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl', 'entity.name.function.preprocessor.ppl']
            expect(lines[0][4]).toEqual value: '(', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl', 'punctuation.definition.parameters.begin.ppl']
            expect(lines[0][5]).toEqual value: 'a', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl', 'variable.parameter.preprocessor.ppl']
            expect(lines[0][6]).toEqual value: ',', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl', 'variable.parameter.preprocessor.ppl', 'punctuation.separator.parameters.ppl']
            expect(lines[0][7]).toEqual value: ' b', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl', 'variable.parameter.preprocessor.ppl']
            expect(lines[0][8]).toEqual value: ')', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl', 'punctuation.definition.parameters.end.ppl']
            expect(lines[0][10]).toEqual value: '{', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl', 'meta.block.ppl', 'punctuation.section.block.begin.ppl']
            expect(lines[0][12]).toEqual value: '\\', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl', 'meta.block.ppl', 'constant.character.escape.line-continuation.ppl']
            expect(lines[1][1]).toEqual value: '^=', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl', 'meta.block.ppl', 'keyword.operator.assignment.compound.bitwise.ppl']
            expect(lines[1][3]).toEqual value: '\\', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl', 'meta.block.ppl', 'constant.character.escape.line-continuation.ppl']
            expect(lines[2][1]).toEqual value: '^=', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl', 'meta.block.ppl', 'keyword.operator.assignment.compound.bitwise.ppl']
            expect(lines[2][3]).toEqual value: '\\', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl', 'meta.block.ppl', 'constant.character.escape.line-continuation.ppl']
            expect(lines[3][1]).toEqual value: '^=', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl', 'meta.block.ppl', 'keyword.operator.assignment.compound.bitwise.ppl']
            expect(lines[3][3]).toEqual value: '\\', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl', 'meta.block.ppl', 'constant.character.escape.line-continuation.ppl']
            expect(lines[4][0]).toEqual value: '}', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl', 'meta.block.ppl', 'punctuation.section.block.end.ppl']

      describe "includes", ->
        it "tokenizes '#include'", ->
          {tokens} = grammar.tokenizeLine '#include <stdio.h>'
          expect(tokens[0]).toEqual value: '#', scopes: ['source.ppl', 'meta.preprocessor.include.ppl', 'keyword.control.directive.include.ppl', 'punctuation.definition.directive.ppl']
          expect(tokens[1]).toEqual value: 'include', scopes: ['source.ppl', 'meta.preprocessor.include.ppl', 'keyword.control.directive.include.ppl']
          expect(tokens[3]).toEqual value: '<', scopes: ['source.ppl', 'meta.preprocessor.include.ppl', 'string.quoted.other.lt-gt.include.ppl', 'punctuation.definition.string.begin.ppl']
          expect(tokens[4]).toEqual value: 'stdio.h', scopes: ['source.ppl', 'meta.preprocessor.include.ppl', 'string.quoted.other.lt-gt.include.ppl']
          expect(tokens[5]).toEqual value: '>', scopes: ['source.ppl', 'meta.preprocessor.include.ppl', 'string.quoted.other.lt-gt.include.ppl', 'punctuation.definition.string.end.ppl']

          {tokens} = grammar.tokenizeLine '#include<stdio.h>'
          expect(tokens[0]).toEqual value: '#', scopes: ['source.ppl', 'meta.preprocessor.include.ppl', 'keyword.control.directive.include.ppl', 'punctuation.definition.directive.ppl']
          expect(tokens[1]).toEqual value: 'include', scopes: ['source.ppl', 'meta.preprocessor.include.ppl', 'keyword.control.directive.include.ppl']
          expect(tokens[2]).toEqual value: '<', scopes: ['source.ppl', 'meta.preprocessor.include.ppl', 'string.quoted.other.lt-gt.include.ppl', 'punctuation.definition.string.begin.ppl']
          expect(tokens[3]).toEqual value: 'stdio.h', scopes: ['source.ppl', 'meta.preprocessor.include.ppl', 'string.quoted.other.lt-gt.include.ppl']
          expect(tokens[4]).toEqual value: '>', scopes: ['source.ppl', 'meta.preprocessor.include.ppl', 'string.quoted.other.lt-gt.include.ppl', 'punctuation.definition.string.end.ppl']

          {tokens} = grammar.tokenizeLine '#include_<stdio.h>'
          expect(tokens[0]).toEqual value: '#include_', scopes: ['source.ppl']

          {tokens} = grammar.tokenizeLine '#include "file"'
          expect(tokens[0]).toEqual value: '#', scopes: ['source.ppl', 'meta.preprocessor.include.ppl', 'keyword.control.directive.include.ppl', 'punctuation.definition.directive.ppl']
          expect(tokens[1]).toEqual value: 'include', scopes: ['source.ppl', 'meta.preprocessor.include.ppl', 'keyword.control.directive.include.ppl']
          expect(tokens[3]).toEqual value: '"', scopes: ['source.ppl', 'meta.preprocessor.include.ppl', 'string.quoted.double.include.ppl', 'punctuation.definition.string.begin.ppl']
          expect(tokens[4]).toEqual value: 'file', scopes: ['source.ppl', 'meta.preprocessor.include.ppl', 'string.quoted.double.include.ppl']
          expect(tokens[5]).toEqual value: '"', scopes: ['source.ppl', 'meta.preprocessor.include.ppl', 'string.quoted.double.include.ppl', 'punctuation.definition.string.end.ppl']

        it "tokenizes '#import'", ->
          {tokens} = grammar.tokenizeLine '#import "file"'
          expect(tokens[0]).toEqual value: '#', scopes: ['source.ppl', 'meta.preprocessor.include.ppl', 'keyword.control.directive.import.ppl', 'punctuation.definition.directive.ppl']
          expect(tokens[1]).toEqual value: 'import', scopes: ['source.ppl', 'meta.preprocessor.include.ppl', 'keyword.control.directive.import.ppl']
          expect(tokens[3]).toEqual value: '"', scopes: ['source.ppl', 'meta.preprocessor.include.ppl', 'string.quoted.double.include.ppl', 'punctuation.definition.string.begin.ppl']
          expect(tokens[4]).toEqual value: 'file', scopes: ['source.ppl', 'meta.preprocessor.include.ppl', 'string.quoted.double.include.ppl']
          expect(tokens[5]).toEqual value: '"', scopes: ['source.ppl', 'meta.preprocessor.include.ppl', 'string.quoted.double.include.ppl', 'punctuation.definition.string.end.ppl']

      describe "diagnostics", ->
        it "tokenizes '#error'", ->
          {tokens} = grammar.tokenizeLine '#error C++ compiler required.'
          expect(tokens[0]).toEqual value: '#', scopes: ['source.ppl', 'meta.preprocessor.diagnostic.ppl', 'keyword.control.directive.diagnostic.error.ppl', 'punctuation.definition.directive.ppl']
          expect(tokens[1]).toEqual value: 'error', scopes: ['source.ppl', 'meta.preprocessor.diagnostic.ppl', 'keyword.control.directive.diagnostic.error.ppl']
          expect(tokens[2]).toEqual value: ' C++ compiler required.', scopes: ['source.ppl', 'meta.preprocessor.diagnostic.ppl']

        it "tokenizes '#warning'", ->
          {tokens} = grammar.tokenizeLine '#warning This is a warning.'
          expect(tokens[0]).toEqual value: '#', scopes: ['source.ppl', 'meta.preprocessor.diagnostic.ppl', 'keyword.control.directive.diagnostic.warning.ppl', 'punctuation.definition.directive.ppl']
          expect(tokens[1]).toEqual value: 'warning', scopes: ['source.ppl', 'meta.preprocessor.diagnostic.ppl', 'keyword.control.directive.diagnostic.warning.ppl']
          expect(tokens[2]).toEqual value: ' This is a warning.', scopes: ['source.ppl', 'meta.preprocessor.diagnostic.ppl']

      describe "conditionals", ->
        it "tokenizes if-elif-else preprocessor blocks", ->
          lines = grammar.tokenizeLines '''
            #if defined(CREDIT)
                credit();
            #elif defined(DEBIT)
                debit();
            #else
                printerror();
            #endif
          '''
          expect(lines[0][0]).toEqual value: '#', scopes: ['source.ppl', 'meta.preprocessor.ppl', 'keyword.control.directive.conditional.ppl', 'punctuation.definition.directive.ppl']
          expect(lines[0][1]).toEqual value: 'if', scopes: ['source.ppl', 'meta.preprocessor.ppl', 'keyword.control.directive.conditional.ppl']
          expect(lines[0][2]).toEqual value: ' defined(CREDIT)', scopes: ['source.ppl', 'meta.preprocessor.ppl']
          expect(lines[1][1]).toEqual value: 'credit', scopes: ['source.ppl', 'meta.function.ppl', 'entity.name.function.ppl']
          expect(lines[1][2]).toEqual value: '(', scopes: ['source.ppl', 'meta.function.ppl', 'meta.parens.ppl', 'punctuation.section.parens.begin.ppl']
          expect(lines[1][3]).toEqual value: ')', scopes: ['source.ppl', 'meta.function.ppl', 'meta.parens.ppl', 'punctuation.section.parens.end.ppl']
          expect(lines[2][0]).toEqual value: '#', scopes: ['source.ppl', 'meta.preprocessor.ppl', 'keyword.control.directive.conditional.ppl', 'punctuation.definition.directive.ppl']
          expect(lines[2][1]).toEqual value: 'elif', scopes: ['source.ppl', 'meta.preprocessor.ppl', 'keyword.control.directive.conditional.ppl']
          expect(lines[2][2]).toEqual value: ' defined(DEBIT)', scopes: ['source.ppl', 'meta.preprocessor.ppl']
          expect(lines[3][1]).toEqual value: 'debit', scopes: ['source.ppl', 'meta.function.ppl', 'entity.name.function.ppl']
          expect(lines[3][2]).toEqual value: '(', scopes: ['source.ppl', 'meta.function.ppl', 'meta.parens.ppl', 'punctuation.section.parens.begin.ppl']
          expect(lines[3][3]).toEqual value: ')', scopes: ['source.ppl', 'meta.function.ppl', 'meta.parens.ppl', 'punctuation.section.parens.end.ppl']
          expect(lines[4][0]).toEqual value: '#', scopes: ['source.ppl', 'meta.preprocessor.ppl', 'keyword.control.directive.conditional.ppl', 'punctuation.definition.directive.ppl']
          expect(lines[4][1]).toEqual value: 'else', scopes: ['source.ppl', 'meta.preprocessor.ppl', 'keyword.control.directive.conditional.ppl']
          expect(lines[5][1]).toEqual value: 'printerror', scopes: ['source.ppl', 'meta.function.ppl', 'entity.name.function.ppl']
          expect(lines[5][2]).toEqual value: '(', scopes: ['source.ppl', 'meta.function.ppl', 'meta.parens.ppl', 'punctuation.section.parens.begin.ppl']
          expect(lines[5][3]).toEqual value: ')', scopes: ['source.ppl', 'meta.function.ppl', 'meta.parens.ppl', 'punctuation.section.parens.end.ppl']
          expect(lines[6][0]).toEqual value: '#', scopes: ['source.ppl', 'meta.preprocessor.ppl', 'keyword.control.directive.conditional.ppl', 'punctuation.definition.directive.ppl']
          expect(lines[6][1]).toEqual value: 'endif', scopes: ['source.ppl', 'meta.preprocessor.ppl', 'keyword.control.directive.conditional.ppl']

        it "tokenizes if-true-else blocks", ->
          lines = grammar.tokenizeLines '''
            #if 1
            int something() {
              #if 1
                return 1;
              #else
                return 0;
              #endif
            }
            #else
            int something() {
              return 0;
            }
            #endif
          '''
          expect(lines[0][0]).toEqual value: '#', scopes: ['source.ppl', 'meta.preprocessor.ppl', 'keyword.control.directive.conditional.ppl', 'punctuation.definition.directive.ppl']
          expect(lines[0][1]).toEqual value: 'if', scopes: ['source.ppl', 'meta.preprocessor.ppl', 'keyword.control.directive.conditional.ppl']
          expect(lines[0][3]).toEqual value: '1', scopes: ['source.ppl', 'meta.preprocessor.ppl', 'constant.numeric.preprocessor.ppl']
          expect(lines[1][0]).toEqual value: 'int', scopes: ['source.ppl', 'storage.type.ppl']
          expect(lines[1][2]).toEqual value: 'something', scopes: ['source.ppl', 'meta.function.ppl', 'entity.name.function.ppl']
          expect(lines[2][1]).toEqual value: '#', scopes: ['source.ppl', 'meta.function.ppl', 'meta.block.ppl', 'meta.preprocessor.ppl', 'keyword.control.directive.conditional.ppl', 'punctuation.definition.directive.ppl']
          expect(lines[2][2]).toEqual value: 'if', scopes: ['source.ppl', 'meta.function.ppl', 'meta.block.ppl', 'meta.preprocessor.ppl', 'keyword.control.directive.conditional.ppl']
          expect(lines[2][4]).toEqual value: '1', scopes: ['source.ppl', 'meta.function.ppl', 'meta.block.ppl', 'meta.preprocessor.ppl', 'constant.numeric.preprocessor.ppl']
          expect(lines[3][1]).toEqual value: 'return', scopes: ['source.ppl', 'meta.function.ppl', 'meta.block.ppl', 'keyword.control.ppl']
          expect(lines[3][3]).toEqual value: '1', scopes: ['source.ppl', 'meta.function.ppl', 'meta.block.ppl', 'constant.numeric.ppl']
          expect(lines[4][1]).toEqual value: '#', scopes: ['source.ppl', 'meta.function.ppl', 'meta.block.ppl', 'meta.preprocessor.ppl', 'keyword.control.directive.conditional.ppl', 'punctuation.definition.directive.ppl']
          expect(lines[4][2]).toEqual value: 'else', scopes: ['source.ppl', 'meta.function.ppl', 'meta.block.ppl', 'meta.preprocessor.ppl', 'keyword.control.directive.conditional.ppl']
          expect(lines[5][0]).toEqual value: '    return 0;', scopes: ['source.ppl', 'meta.function.ppl', 'meta.block.ppl', 'comment.block.preprocessor.else-branch.in-block']
          expect(lines[6][1]).toEqual value: '#', scopes: ['source.ppl', 'meta.function.ppl', 'meta.block.ppl', 'meta.preprocessor.ppl', 'keyword.control.directive.conditional.ppl', 'punctuation.definition.directive.ppl']
          expect(lines[6][2]).toEqual value: 'endif', scopes: ['source.ppl', 'meta.function.ppl', 'meta.block.ppl', 'meta.preprocessor.ppl', 'keyword.control.directive.conditional.ppl']
          expect(lines[8][0]).toEqual value: '#', scopes: ['source.ppl', 'meta.preprocessor.ppl', 'keyword.control.directive.conditional.ppl', 'punctuation.definition.directive.ppl']
          expect(lines[8][1]).toEqual value: 'else', scopes: ['source.ppl', 'meta.preprocessor.ppl', 'keyword.control.directive.conditional.ppl']
          expect(lines[9][0]).toEqual value: 'int something() {', scopes: ['source.ppl', 'comment.block.preprocessor.else-branch']
          expect(lines[12][0]).toEqual value: '#', scopes: ['source.ppl', 'meta.preprocessor.ppl', 'keyword.control.directive.conditional.ppl', 'punctuation.definition.directive.ppl']
          expect(lines[12][1]).toEqual value: 'endif', scopes: ['source.ppl', 'meta.preprocessor.ppl', 'keyword.control.directive.conditional.ppl']

        it "tokenizes if-false-else blocks", ->
          lines = grammar.tokenizeLines '''
            int something() {
              #if 0
                return 1;
              #else
                return 0;
              #endif
            }
          '''
          expect(lines[0][0]).toEqual value: 'int', scopes: ['source.ppl', 'storage.type.ppl']
          expect(lines[0][2]).toEqual value: 'something', scopes: ['source.ppl', 'meta.function.ppl', 'entity.name.function.ppl']
          expect(lines[1][1]).toEqual value: '#', scopes: ['source.ppl', 'meta.function.ppl', 'meta.block.ppl', 'meta.preprocessor.ppl', 'keyword.control.directive.conditional.ppl', 'punctuation.definition.directive.ppl']
          expect(lines[1][2]).toEqual value: 'if', scopes: ['source.ppl', 'meta.function.ppl', 'meta.block.ppl', 'meta.preprocessor.ppl', 'keyword.control.directive.conditional.ppl']
          expect(lines[1][4]).toEqual value: '0', scopes: ['source.ppl', 'meta.function.ppl', 'meta.block.ppl', 'meta.preprocessor.ppl', 'constant.numeric.preprocessor.ppl']
          expect(lines[2][0]).toEqual value: '    return 1;', scopes: ['source.ppl', 'meta.function.ppl', 'meta.block.ppl', 'comment.block.preprocessor.if-branch.in-block']
          expect(lines[3][1]).toEqual value: '#', scopes: ['source.ppl', 'meta.function.ppl', 'meta.block.ppl', 'meta.preprocessor.ppl', 'keyword.control.directive.conditional.ppl', 'punctuation.definition.directive.ppl']
          expect(lines[3][2]).toEqual value: 'else', scopes: ['source.ppl', 'meta.function.ppl', 'meta.block.ppl', 'meta.preprocessor.ppl', 'keyword.control.directive.conditional.ppl']
          expect(lines[4][1]).toEqual value: 'return', scopes: ['source.ppl', 'meta.function.ppl', 'meta.block.ppl', 'keyword.control.ppl']
          expect(lines[4][3]).toEqual value: '0', scopes: ['source.ppl', 'meta.function.ppl', 'meta.block.ppl', 'constant.numeric.ppl']
          expect(lines[5][1]).toEqual value: '#', scopes: ['source.ppl', 'meta.function.ppl', 'meta.block.ppl', 'meta.preprocessor.ppl', 'keyword.control.directive.conditional.ppl', 'punctuation.definition.directive.ppl']
          expect(lines[5][2]).toEqual value: 'endif', scopes: ['source.ppl', 'meta.function.ppl', 'meta.block.ppl', 'meta.preprocessor.ppl', 'keyword.control.directive.conditional.ppl']

          lines = grammar.tokenizeLines '''
            #if 0
              something();
            #endif
          '''
          expect(lines[0][0]).toEqual value: '#', scopes: ['source.ppl', 'meta.preprocessor.ppl', 'keyword.control.directive.conditional.ppl', 'punctuation.definition.directive.ppl']
          expect(lines[0][1]).toEqual value: 'if', scopes: ['source.ppl', 'meta.preprocessor.ppl', 'keyword.control.directive.conditional.ppl']
          expect(lines[0][3]).toEqual value: '0', scopes: ['source.ppl', 'meta.preprocessor.ppl', 'constant.numeric.preprocessor.ppl']
          expect(lines[1][0]).toEqual value: '  something();', scopes: ['source.ppl', 'comment.block.preprocessor.if-branch']
          expect(lines[2][0]).toEqual value: '#', scopes: ['source.ppl', 'meta.preprocessor.ppl', 'keyword.control.directive.conditional.ppl', 'punctuation.definition.directive.ppl']
          expect(lines[2][1]).toEqual value: 'endif', scopes: ['source.ppl', 'meta.preprocessor.ppl', 'keyword.control.directive.conditional.ppl']

        it "tokenizes ifdef-elif blocks", ->
          lines = grammar.tokenizeLines '''
            #ifdef __unix__ /* is defined by compilers targeting Unix systems */
              # include <unistd.h>
            #elif defined _WIN32 /* is defined by compilers targeting Windows systems */
              # include <windows.h>
            #endif
          '''
          expect(lines[0][0]).toEqual value: '#', scopes: ['source.ppl', 'meta.preprocessor.ppl', 'keyword.control.directive.conditional.ppl', 'punctuation.definition.directive.ppl']
          expect(lines[0][1]).toEqual value: 'ifdef', scopes: ['source.ppl', 'meta.preprocessor.ppl', 'keyword.control.directive.conditional.ppl']
          expect(lines[0][2]).toEqual value: ' __unix__ ', scopes: ['source.ppl', 'meta.preprocessor.ppl']
          expect(lines[0][3]).toEqual value: '/*', scopes: ['source.ppl', 'comment.block.ppl', 'punctuation.definition.comment.begin.ppl']
          expect(lines[0][4]).toEqual value: ' is defined by compilers targeting Unix systems ', scopes: ['source.ppl', 'comment.block.ppl']
          expect(lines[0][5]).toEqual value: '*/', scopes: ['source.ppl', 'comment.block.ppl', 'punctuation.definition.comment.end.ppl']
          expect(lines[1][1]).toEqual value: '#', scopes: ['source.ppl', 'meta.preprocessor.include.ppl', 'keyword.control.directive.include.ppl', 'punctuation.definition.directive.ppl']
          expect(lines[1][2]).toEqual value: ' include', scopes: ['source.ppl', 'meta.preprocessor.include.ppl', 'keyword.control.directive.include.ppl']
          expect(lines[1][4]).toEqual value: '<', scopes: ['source.ppl', 'meta.preprocessor.include.ppl', 'string.quoted.other.lt-gt.include.ppl', 'punctuation.definition.string.begin.ppl']
          expect(lines[1][5]).toEqual value: 'unistd.h', scopes: ['source.ppl', 'meta.preprocessor.include.ppl', 'string.quoted.other.lt-gt.include.ppl']
          expect(lines[1][6]).toEqual value: '>', scopes: ['source.ppl', 'meta.preprocessor.include.ppl', 'string.quoted.other.lt-gt.include.ppl', 'punctuation.definition.string.end.ppl']
          expect(lines[2][0]).toEqual value: '#', scopes: ['source.ppl', 'meta.preprocessor.ppl', 'keyword.control.directive.conditional.ppl', 'punctuation.definition.directive.ppl']
          expect(lines[2][1]).toEqual value: 'elif', scopes: ['source.ppl', 'meta.preprocessor.ppl', 'keyword.control.directive.conditional.ppl']
          expect(lines[2][2]).toEqual value: ' defined _WIN32 ', scopes: ['source.ppl', 'meta.preprocessor.ppl']
          expect(lines[2][3]).toEqual value: '/*', scopes: ['source.ppl', 'comment.block.ppl', 'punctuation.definition.comment.begin.ppl']
          expect(lines[2][4]).toEqual value: ' is defined by compilers targeting Windows systems ', scopes: ['source.ppl', 'comment.block.ppl']
          expect(lines[2][5]).toEqual value: '*/', scopes: ['source.ppl', 'comment.block.ppl', 'punctuation.definition.comment.end.ppl']
          expect(lines[3][1]).toEqual value: '#', scopes: ['source.ppl', 'meta.preprocessor.include.ppl', 'keyword.control.directive.include.ppl', 'punctuation.definition.directive.ppl']
          expect(lines[3][2]).toEqual value: ' include', scopes: ['source.ppl', 'meta.preprocessor.include.ppl', 'keyword.control.directive.include.ppl']
          expect(lines[3][4]).toEqual value: '<', scopes: ['source.ppl', 'meta.preprocessor.include.ppl', 'string.quoted.other.lt-gt.include.ppl', 'punctuation.definition.string.begin.ppl']
          expect(lines[3][5]).toEqual value: 'windows.h', scopes: ['source.ppl', 'meta.preprocessor.include.ppl', 'string.quoted.other.lt-gt.include.ppl']
          expect(lines[3][6]).toEqual value: '>', scopes: ['source.ppl', 'meta.preprocessor.include.ppl', 'string.quoted.other.lt-gt.include.ppl', 'punctuation.definition.string.end.ppl']
          expect(lines[4][0]).toEqual value: '#', scopes: ['source.ppl', 'meta.preprocessor.ppl', 'keyword.control.directive.conditional.ppl', 'punctuation.definition.directive.ppl']
          expect(lines[4][1]).toEqual value: 'endif', scopes: ['source.ppl', 'meta.preprocessor.ppl', 'keyword.control.directive.conditional.ppl']

        it "tokenizes ifndef blocks", ->
          lines = grammar.tokenizeLines '''
            #ifndef _INCL_GUARD
              #define _INCL_GUARD
            #endif
          '''
          expect(lines[0][0]).toEqual value: '#', scopes: ['source.ppl', 'meta.preprocessor.ppl', 'keyword.control.directive.conditional.ppl', 'punctuation.definition.directive.ppl']
          expect(lines[0][1]).toEqual value: 'ifndef', scopes: ['source.ppl', 'meta.preprocessor.ppl', 'keyword.control.directive.conditional.ppl']
          expect(lines[0][2]).toEqual value: ' _INCL_GUARD', scopes: ['source.ppl', 'meta.preprocessor.ppl']
          expect(lines[1][1]).toEqual value: '#', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl', 'keyword.control.directive.define.ppl', 'punctuation.definition.directive.ppl']
          expect(lines[1][2]).toEqual value: 'define', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl', 'keyword.control.directive.define.ppl']
          expect(lines[1][4]).toEqual value: '_INCL_GUARD', scopes: ['source.ppl', 'meta.preprocessor.macro.ppl', 'entity.name.function.preprocessor.ppl']
          expect(lines[2][0]).toEqual value: '#', scopes: ['source.ppl', 'meta.preprocessor.ppl', 'keyword.control.directive.conditional.ppl', 'punctuation.definition.directive.ppl']
          expect(lines[2][1]).toEqual value: 'endif', scopes: ['source.ppl', 'meta.preprocessor.ppl', 'keyword.control.directive.conditional.ppl']

    describe "indentation", ->
      editor = null

      beforeEach ->
        editor = buildTextEditor()
        editor.setGrammar(grammar)

      expectPreservedIndentation = (text) ->
        editor.setText(text)
        editor.autoIndentBufferRows(0, editor.getLineCount() - 1)

        expectedLines = text.split('\n')
        actualLines = editor.getText().split('\n')
        for actualLine, i in actualLines
          expect([
            actualLine,
            editor.indentLevelForLine(actualLine)
          ]).toEqual([
            expectedLines[i],
            editor.indentLevelForLine(expectedLines[i])
          ])

      it "indents allman-style curly braces", ->
        expectPreservedIndentation '''
          if (a)
          {
            for (;;)
            {
              do
              {
                while (b)
                {
                  c();
                }
              }
              while (d)
            }
          }
        '''

      it "indents non-allman-style curly braces", ->
        expectPreservedIndentation '''
          if (a) {
            for (;;) {
              do {
                while (b) {
                  c();
                }
              } while (d)
            }
          }
        '''

      it "indents function arguments", ->
        expectPreservedIndentation '''
          a(
            b,
            c(
              d
            )
          );
        '''

      it "indents array and struct literals", ->
        expectPreservedIndentation '''
          some_t a[3] = {
            { .b = c },
            { .b = c, .d = {1, 2} },
          };
        '''

      it "tokenizes binary literal", ->
        {tokens} = grammar.tokenizeLine '0b101010'
        expect(tokens[0]).toEqual value: '0b101010', scopes: ['source.ppl', 'constant.numeric.ppl']

    describe "access", ->
      it "should tokenizes dot access", ->
        lines = grammar.tokenizeLines '''
          int main() {
            A a;
            a.b = NULL;
            return 0;
          }
        '''

        expect(lines[2][0]).toEqual value: '  a', scopes: ['source.ppl', 'meta.function.ppl', 'meta.block.ppl']
        expect(lines[2][1]).toEqual value: '.', scopes: ['source.ppl', 'meta.function.ppl', 'meta.block.ppl', 'punctuation.separator.dot-access.ppl']
        expect(lines[2][2]).toEqual value: 'b', scopes: ['source.ppl', 'meta.function.ppl', 'meta.block.ppl', 'variable.other.member.ppl']

      it "should tokenizes pointer access", ->
        lines = grammar.tokenizeLines '''
          int main() {
            A *a;
            a->b = NULL;
            return 0;
          }
        '''

        expect(lines[2][0]).toEqual value: '  a', scopes: ['source.ppl', 'meta.function.ppl', 'meta.block.ppl']
        expect(lines[2][1]).toEqual value: '->', scopes: ['source.ppl', 'meta.function.ppl', 'meta.block.ppl', 'punctuation.separator.pointer-access.ppl']
        expect(lines[2][2]).toEqual value: 'b', scopes: ['source.ppl', 'meta.function.ppl', 'meta.block.ppl', 'variable.other.member.ppl']

    describe "operators", ->
      it "tokenizes the sizeof operator", ->
        {tokens} = grammar.tokenizeLine('sizeof unary_expression')
        expect(tokens[0]).toEqual value: 'sizeof', scopes: ['source.ppl', 'keyword.operator.sizeof.ppl']
        expect(tokens[1]).toEqual value: ' unary_expression', scopes: ['source.ppl']

        {tokens} = grammar.tokenizeLine('sizeof (int)')
        expect(tokens[0]).toEqual value: 'sizeof', scopes: ['source.ppl', 'keyword.operator.sizeof.ppl']
        expect(tokens[1]).toEqual value: ' (', scopes: ['source.ppl']
        expect(tokens[2]).toEqual value: 'int', scopes: ['source.ppl', 'storage.type.ppl']
        expect(tokens[3]).toEqual value: ')', scopes: ['source.ppl']

        {tokens} = grammar.tokenizeLine('$sizeof')
        expect(tokens[1]).not.toEqual value: 'sizeof', scopes: ['source.ppl', 'keyword.operator.sizeof.ppl']

        {tokens} = grammar.tokenizeLine('sizeof$')
        expect(tokens[0]).not.toEqual value: 'sizeof', scopes: ['source.ppl', 'keyword.operator.sizeof.ppl']

        {tokens} = grammar.tokenizeLine('sizeof_')
        expect(tokens[0]).not.toEqual value: 'sizeof', scopes: ['source.ppl', 'keyword.operator.sizeof.ppl']

      it "tokenizes the increment operator", ->
        {tokens} = grammar.tokenizeLine('i++')
        expect(tokens[0]).toEqual value: 'i', scopes: ['source.ppl']
        expect(tokens[1]).toEqual value: '++', scopes: ['source.ppl', 'keyword.operator.increment.ppl']

        {tokens} = grammar.tokenizeLine('++i')
        expect(tokens[0]).toEqual value: '++', scopes: ['source.ppl', 'keyword.operator.increment.ppl']
        expect(tokens[1]).toEqual value: 'i', scopes: ['source.ppl']

      it "tokenizes the decrement operator", ->
        {tokens} = grammar.tokenizeLine('i--')
        expect(tokens[0]).toEqual value: 'i', scopes: ['source.ppl']
        expect(tokens[1]).toEqual value: '--', scopes: ['source.ppl', 'keyword.operator.decrement.ppl']

        {tokens} = grammar.tokenizeLine('--i')
        expect(tokens[0]).toEqual value: '--', scopes: ['source.ppl', 'keyword.operator.decrement.ppl']
        expect(tokens[1]).toEqual value: 'i', scopes: ['source.ppl']

      it "tokenizes logical operators", ->
        {tokens} = grammar.tokenizeLine('!a')
        expect(tokens[0]).toEqual value: '!', scopes: ['source.ppl', 'keyword.operator.logical.ppl']
        expect(tokens[1]).toEqual value: 'a', scopes: ['source.ppl']

        operators = ['&&', '||']
        for operator in operators
          {tokens} = grammar.tokenizeLine('a ' + operator + ' b')
          expect(tokens[0]).toEqual value: 'a ', scopes: ['source.ppl']
          expect(tokens[1]).toEqual value: operator, scopes: ['source.ppl', 'keyword.operator.logical.ppl']
          expect(tokens[2]).toEqual value: ' b', scopes: ['source.ppl']

      it "tokenizes comparison operators", ->
        operators = ['<=', '>=', '!=', '==', '<', '>' ]

        for operator in operators
          {tokens} = grammar.tokenizeLine('a ' + operator + ' b')
          expect(tokens[0]).toEqual value: 'a ', scopes: ['source.ppl']
          expect(tokens[1]).toEqual value: operator, scopes: ['source.ppl', 'keyword.operator.comparison.ppl']
          expect(tokens[2]).toEqual value: ' b', scopes: ['source.ppl']

      it "tokenizes arithmetic operators", ->
        operators = ['+', '-', '*', '/', '%']

        for operator in operators
          {tokens} = grammar.tokenizeLine('a ' + operator + ' b')
          expect(tokens[0]).toEqual value: 'a ', scopes: ['source.ppl']
          expect(tokens[1]).toEqual value: operator, scopes: ['source.ppl', 'keyword.operator.ppl']
          expect(tokens[2]).toEqual value: ' b', scopes: ['source.ppl']

      it "tokenizes ternary operators", ->
        {tokens} = grammar.tokenizeLine('a ? b : c')
        expect(tokens[0]).toEqual value: 'a ', scopes: ['source.ppl']
        expect(tokens[1]).toEqual value: '?', scopes: ['source.ppl', 'keyword.operator.ternary.ppl']
        expect(tokens[2]).toEqual value: ' b ', scopes: ['source.ppl']
        expect(tokens[3]).toEqual value: ':', scopes: ['source.ppl', 'keyword.operator.ternary.ppl']
        expect(tokens[4]).toEqual value: ' c', scopes: ['source.ppl']

      describe "bitwise", ->
        it "tokenizes bitwise 'not'", ->
          {tokens} = grammar.tokenizeLine('~a')
          expect(tokens[0]).toEqual value: '~', scopes: ['source.ppl', 'keyword.operator.ppl']
          expect(tokens[1]).toEqual value: 'a', scopes: ['source.ppl']

        it "tokenizes shift operators", ->
          {tokens} = grammar.tokenizeLine('>>')
          expect(tokens[0]).toEqual value: '>>', scopes: ['source.ppl', 'keyword.operator.bitwise.shift.ppl']

          {tokens} = grammar.tokenizeLine('<<')
          expect(tokens[0]).toEqual value: '<<', scopes: ['source.ppl', 'keyword.operator.bitwise.shift.ppl']

        it "tokenizes them", ->
          operators = ['|', '^', '&']

          for operator in operators
            {tokens} = grammar.tokenizeLine('a ' + operator + ' b')
            expect(tokens[0]).toEqual value: 'a ', scopes: ['source.ppl']
            expect(tokens[1]).toEqual value: operator, scopes: ['source.ppl', 'keyword.operator.ppl']
            expect(tokens[2]).toEqual value: ' b', scopes: ['source.ppl']

      describe "assignment", ->
        it "tokenizes the assignment operator", ->
          {tokens} = grammar.tokenizeLine('a = b')
          expect(tokens[0]).toEqual value: 'a ', scopes: ['source.ppl']
          expect(tokens[1]).toEqual value: '=', scopes: ['source.ppl', 'keyword.operator.assignment.ppl']
          expect(tokens[2]).toEqual value: ' b', scopes: ['source.ppl']

        it "tokenizes compound assignment operators", ->
          operators = ['+=', '-=', '*=', '/=', '%=']
          for operator in operators
            {tokens} = grammar.tokenizeLine('a ' + operator + ' b')
            expect(tokens[0]).toEqual value: 'a ', scopes: ['source.ppl']
            expect(tokens[1]).toEqual value: operator, scopes: ['source.ppl', 'keyword.operator.assignment.compound.ppl']
            expect(tokens[2]).toEqual value: ' b', scopes: ['source.ppl']

        it "tokenizes bitwise compound operators", ->
          operators = ['<<=', '>>=', '&=', '^=', '|=']
          for operator in operators
            {tokens} = grammar.tokenizeLine('a ' + operator + ' b')
            expect(tokens[0]).toEqual value: 'a ', scopes: ['source.ppl']
            expect(tokens[1]).toEqual value: operator, scopes: ['source.ppl', 'keyword.operator.assignment.compound.bitwise.ppl']
            expect(tokens[2]).toEqual value: ' b', scopes: ['source.ppl']
