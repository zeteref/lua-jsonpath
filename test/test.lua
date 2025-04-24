--[[

    This file is part of lua-jsonpath.

    Copyright (c) 2016 Frank Edelhaeuser

    Permission is hereby granted, free of charge, to any person obtaining a
    copy of this software and associated documentation files (the "Software"),
    to deal in the Software without restriction, including without limitation
    the rights to use, copy, modify, merge, publish, distribute, sublicense,
    and/or sell copies of the Software, and to permit persons to whom the
    Software is furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included
    in all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
    OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
    MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
    IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
    CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
    TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
    SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


    Lua JsonPath test suite
    =======================

    Applicable test cases ported over from https://github.com/dchester/jsonpath
    Additional test cases added for lua-jsonpath

    Install dependencies:

        luarocks install jsonpath

        git clone https://github.com/bluebird75/luaunit
        cd luaunit
        sudo python doit.py install

    Usage:

        lua test.lua

]]
--
local lu = require("luaunit")

-- For grammer tests
local lpeg = require("lpeg")

-- Module under test
package.path = "../?.lua;" .. package.path
local jp = require("jsonpath")

-- Test store
local store = {}
local employees = {}
local data = require("data")

employees = data.employees
store.store = data.store

-- Helper: sort node table by path
function sortByPath(nodes)
  local sorted = {}
  for _, v in pairs(nodes) do
    table.insert(sorted, v)
  end
  table.sort(sorted, function(a, b)
    return table.concat(a.path, ".") < table.concat(b.path, ".")
  end)
  return sorted
end

testParse = {

  testShouldParseRootOnly = function()
    local path, err = jp.parse("$")
    lu.assertNil(err)
    lu.assertEquals(path, { "$" })
  end,

  testParsePathForStore = function()
    local path, err = jp.parse("$.store")
    lu.assertNil(err)
    lu.assertEquals(path, { "$", "store" })
  end,

  testParsePathForTheAuthorsOfAllBooksInTheStore = function()
    local path, err = jp.parse("$.store.book[*].author")
    lu.assertNil(err)
    lu.assertEquals(path, { "$", "store", "book", { "*" }, "author" })
  end,

  testParsePathForAllAuthors = function()
    local path, err = jp.parse("$..author")
    lu.assertNil(err)
    lu.assertEquals(path, { "$", "..", "author" })
  end,

  testParsePathForAllThingsInStore = function()
    local path, err = jp.parse("$.store.*")
    lu.assertNil(err)
    lu.assertEquals(path, { "$", "store", "*" })
  end,

  testParsePathForPriceOfEverythingInTheStore = function()
    local path, err = jp.parse("$.store..price")
    lu.assertNil(err)
    lu.assertEquals(path, { "$", "store", "..", "price" })
  end,

  testParsePathForTheLastBookInOrderViaExpression = function()
    local path, err = jp.parse("$..book[(@.length-1)]")
    lu.assertNil(err)
    lu.assertEquals(
      path,
      { "$", "..", "book", { "union", { "expr", { "expr", { "var.length" }, "-", { "expr", 1 } } } } }
    )
  end,

  testParsePathForTheFirstTwoBooksViaUnion = function()
    local path, err = jp.parse("$..book[0,1]")
    lu.assertNil(err)
    lu.assertNotNil(path)
    lu.assertEquals(path, { "$", "..", "book", { "union", "0", "1" } })
  end,

  testParsePathForTheFirstTwoBooksViaSlice = function()
    local path, err = jp.parse("$..book[0:2]")
    lu.assertNil(err)
    lu.assertEquals(path, { "$", "..", "book", { "union", { "slice", "0", "2", "1" } } })
  end,

  testParsePathToFilterAllBooksWithIsbnNumber = function()
    local path, err = jp.parse("$..book[?(@.isbn)]")
    lu.assertNil(err)
    lu.assertEquals(path, { "$", "..", "book", { "filter", { "expr", { "var", "isbn" } } } })
  end,

  testParsePathToFilterAllBooksWithAPriceLessThan10 = function()
    local path, err = jp.parse("$..book[?(@.price<10)]")
    lu.assertNil(err)
    lu.assertEquals(path, {
      "$",
      "..",
      "book",
      { "filter", { "expr", { "expr", { "var", "price" }, "<", { "expr", 10 } } } },
    })
  end,

  testParsePathToMatchAllElements = function()
    local path, err = jp.parse("$..*")
    lu.assertNil(err)
    lu.assertEquals(path, { "$", "..", "*" })
  end,

  testParsePathWithLeadingMember = function()
    local path, err = jp.parse("store")
    lu.assertNil(err)
    lu.assertEquals(path, { "$", "store" })
  end,

  testParsePathWithLeadingMemberAndFollowers = function()
    local path, err = jp.parse("Request.prototype.end")
    lu.assertNil(err)
    lu.assertEquals(path, { "$", "Request", "prototype", "end" })
  end,

  testParserAstIsReinitializedAfterParseThrows = function()
    lu.assertNil(jp.parse("store.book..."))
    local path, err = jp.parse("$..price")
    lu.assertNil(err)
    lu.assertEquals(path, { "$", "..", "price" })
  end,
}

testParseLuaPort = {
  testParseAllElementsViaSubscriptWildcard = function()
    local path, err = jp.parse("$..[*]")
    lu.assertNil(err)
    lu.assertEquals(path, { "$", "..", { "*" } })
  end,

  testParseObjectSubscriptWildcard = function()
    local path, err = jp.parse("$.store[*]")
    lu.assertNil(err)
    lu.assertEquals(path, { "$", "store", { "*" } })
  end,

  testParseMemberNumericLiteralGetsFirstElement = function()
    local path, err = jp.parse("$.store.book.0")
    lu.assertNil(err)
    lu.assertEquals(path, { "$", "store", "book", "0" })
  end,

  testParseDescendantNumericLiteralGetsFirstElement = function()
    local path, err = jp.parse("$.store.book..0")
    lu.assertNil(err)
    lu.assertEquals(path, { "$", "store", "book", "..", "0" })
  end,

  test_SubscriptDoubleQuotedString = function()
    local path, err = jp.parse('$["store"]')
    lu.assertNil(err)
    lu.assertEquals(path, { "$", { "union", "store" } })
  end,

  testSubscriptSingleQuotedString = function()
    local path, err = jp.parse("$['store']")
    lu.assertNil(err)
    lu.assertEquals(path, { "$", { "union", "store" } })
  end,

  testParseUnionOfThreeArraySlices = function()
    local path, err = jp.parse("$.store.book[0:1,1:2,2:3]")
    lu.assertNil(err)
    lu.assertEquals(path, {
      "$",
      "store",
      "book",
      {
        "union",
        { "slice", "0", "1", "1" },
        { "slice", "1", "2", "1" },
        { "slice", "2", "3", "1" },
      },
    })
  end,

  testParseSliceWithStepGreaterThan1 = function()
    local path, err = jp.parse("$.store.book[0:4:2]")
    lu.assertNil(err)
    lu.assertEquals(path, { "$", "store", "book", { "union", { "slice", "0", "4", "2" } } })
  end,

  testParseUnionOfSubscriptStringLiteralKeys = function()
    local path, err = jp.parse("$.store['book','bicycle']")
    lu.assertNil(err)
    lu.assertEquals(path, { "$", "store", { "union", "book", "bicycle" } })
  end,

  testParseUnionOfSubscriptStringLiteralThreeKeys = function()
    local path, err = jp.parse("$.store.book[1]['title','author','price']")
    lu.assertNil(err)
    lu.assertEquals(path, { "$", "store", "book", { "union", "1" }, { "union", "title", "author", "price" } })
  end,

  testParseUnionOfSubscriptIntegerThreeKeysFollowedByMemberChildIdentifier = function()
    local path, err = jp.parse("$.store.book[1,2,3]['title']")
    lu.assertNil(err)
    lu.assertEquals(path, { "$", "store", "book", { "union", "1", "2", "3" }, { "union", "title" } })
  end,

  testParseUnionOfSubscriptIntegerThreeKeysFollowedByUnionOfSubscriptStringLiteralThreeKeys = function()
    local path, err = jp.parse("$.store.book[0,1,2,3]['title','author','price']")
    lu.assertNil(err)
    lu.assertEquals(
      path,
      { "$", "store", "book", { "union", "0", "1", "2", "3" }, { "union", "title", "author", "price" } }
    )
  end,

  testParseUnionOfSubscript4ArraySlicesFollowedByUnionOfSubscriptStringLiteralThreeKeys = function()
    local path, err = jp.parse("$.store.book[0:1,1:2,2:3,3:4]['title','author','price']")
    lu.assertNil(err)
    lu.assertEquals(path, {
      "$",
      "store",
      "book",
      {
        "union",
        { "slice", "0", "1", "1" },
        { "slice", "1", "2", "1" },
        { "slice", "2", "3", "1" },
        { "slice", "3", "4", "1" },
      },
      { "union", "title", "author", "price" },
    })
  end,

  testParseNestedParenthesesEval = function()
    local path, err = jp.parse("$..book[?( @.length && (@.price.max - @.price.min + 20 > 50 || false) )]")
    lu.assertNil(err)
    lu.assertEquals(path, {
      "$",
      "..",
      "book",
      {
        "filter",
        {
          "expr",
          {
            "expr",
            { "var.length" },
            "&&",
            {
              "expr",
              {
                "expr",
                {
                  "expr",
                  { "var", "price", "max" },
                  "-",
                  { "var", "price", "min" },
                  "+",
                  { "expr", 20 },
                },
                ">",
                { "expr", 50 },
              },
              "||",
              { "expr", false },
            },
          },
        },
      },
    })
  end,
}

testParseNegative = {

  testParsePathWithLeadingMemberComponentThrows = function()
    local ast, err = jp.parse(".store")
    lu.assertNil(ast)
    lu.assertNotNil(err)
  end,

  testParsePathWithLeadingDescendantMemberThrows = function()
    local ast, err = jp.parse("..store")
    lu.assertNil(ast)
    lu.assertNotNil(err)
  end,

  testLeadingScriptThrows = function()
    local ast, err = jp.parse("()")
    lu.assertNil(ast)
    lu.assertNotNil(err)
  end,
}

testQuery = {

  testFirstLevelMember = function()
    local results, err = jp.nodes(store, "$.store")
    lu.assertNil(err)
    lu.assertItemsEquals(results, { { path = { "$", "store" }, value = store.store } })
  end,

  testAuthorsOfAllBooksInTheStore = function()
    local results, err = jp.nodes(store, "$.store.book[*].author")
    lu.assertNil(err)
    lu.assertItemsEquals(
      results,
      sortByPath({
        { path = { "$", "store", "book", 0, "author" }, value = "Nigel Rees" },
        { path = { "$", "store", "book", 1, "author" }, value = "Evelyn Waugh" },
        { path = { "$", "store", "book", 2, "author" }, value = "Herman Melville" },
        { path = { "$", "store", "book", 3, "author" }, value = "J. R. R. Tolkien" },
      })
    )
  end,

  testAllAuthors = function()
    local results, err = jp.nodes(store, "$..author")
    lu.assertNil(err)
    lu.assertItemsEquals(
      results,
      sortByPath({
        { path = { "$", "store", "book", 0, "author" }, value = "Nigel Rees" },
        { path = { "$", "store", "book", 1, "author" }, value = "Evelyn Waugh" },
        { path = { "$", "store", "book", 2, "author" }, value = "Herman Melville" },
        { path = { "$", "store", "book", 3, "author" }, value = "J. R. R. Tolkien" },
      })
    )
  end,

  testAllThingsInStore = function()
    local results, err = jp.nodes(store, "$.store.*")
    lu.assertNil(err)
    lu.assertItemsEquals(
      results,
      sortByPath({
        { path = { "$", "store", "book" }, value = store.store.book },
        { path = { "$", "store", "bicycle" }, value = store.store.bicycle },
      })
    )
  end,

  testPriceOfEverythingInTheStore = function()
    local results, err = jp.nodes(store, "$.store..price")
    lu.assertNil(err)
    lu.assertItemsEquals(
      results,
      sortByPath({
        { path = { "$", "store", "book", 0, "price" }, value = 8.95 },
        { path = { "$", "store", "book", 1, "price" }, value = 12.99 },
        { path = { "$", "store", "book", 2, "price" }, value = 8.99 },
        { path = { "$", "store", "book", 3, "price" }, value = 22.99 },
        { path = { "$", "store", "bicycle", "price" }, value = 19.95 },
      })
    )
  end,

  testLastBookInOrderViaExpression = function()
    local results, err = jp.nodes(store, "$..book[(@.length-1)]")
    lu.assertNil(err)
    lu.assertItemsEquals(results, {
      { path = { "$", "store", "book", 3 }, value = store.store.book[4] },
    })
  end,

  testFirstTwoBooksViaUnion = function()
    local results, err = jp.nodes(store, "$..book[0,1]")
    lu.assertNil(err)
    lu.assertItemsEquals(
      results,
      sortByPath({
        { path = { "$", "store", "book", 0 }, value = store.store.book[1] },
        { path = { "$", "store", "book", 1 }, value = store.store.book[2] },
      })
    )
  end,

  testFirstTwoBooksViaSlice = function()
    local results, err = jp.nodes(store, "$..book[0:2]")
    lu.assertNil(err)
    lu.assertItemsEquals(
      results,
      sortByPath({
        { path = { "$", "store", "book", 0 }, value = store.store.book[1] },
        { path = { "$", "store", "book", 1 }, value = store.store.book[2] },
      })
    )
  end,

  testFilterAllBooksWithIsbnNumber = function()
    local results, err = jp.nodes(store, "$..book[?(@.isbn)]")
    lu.assertNil(err)
    lu.assertItemsEquals(
      results,
      sortByPath({
        { path = { "$", "store", "book", 2 }, value = store.store.book[3] },
        { path = { "$", "store", "book", 3 }, value = store.store.book[4] },
      })
    )
  end,

  testFilterAllBooksWithAPriceLessThan10 = function()
    local results, err = jp.nodes(store, "$..book[?(@.price<10)]")
    lu.assertNil(err)
    lu.assertItemsEquals(results, {
      { path = { "$", "store", "book", 0 }, value = store.store.book[1] },
      { path = { "$", "store", "book", 2 }, value = store.store.book[3] },
    })
  end,

  testFirstTenOfAllElements = function()
    local results, err = jp.nodes(store, "$..*", 10)
    lu.assertNil(err)
    lu.assertIsTable(results)
    lu.assertEquals(#results, 10)
  end,

  testAllElements = function()
    local results, err = jp.nodes(store, "$..*")
    lu.assertNil(err)
    lu.assertItemsEquals(
      results,
      sortByPath({
        { path = { "$", "store" }, value = store.store },
        { path = { "$", "store", "book" }, value = store.store.book },
        { path = { "$", "store", "bicycle" }, value = store.store.bicycle },
        { path = { "$", "store", "book", 0 }, value = store.store.book[1] },
        { path = { "$", "store", "book", 1 }, value = store.store.book[2] },
        { path = { "$", "store", "book", 2 }, value = store.store.book[3] },
        { path = { "$", "store", "book", 3 }, value = store.store.book[4] },
        { path = { "$", "store", "book", 0, "category" }, value = "reference" },
        { path = { "$", "store", "book", 0, "author" }, value = "Nigel Rees" },
        { path = { "$", "store", "book", 0, "title" }, value = "Sayings of the Century" },
        { path = { "$", "store", "book", 0, "price" }, value = 8.95 },
        { path = { "$", "store", "book", 1, "category" }, value = "fiction" },
        { path = { "$", "store", "book", 1, "author" }, value = "Evelyn Waugh" },
        { path = { "$", "store", "book", 1, "title" }, value = "Sword of Honour" },
        { path = { "$", "store", "book", 1, "price" }, value = 12.99 },
        { path = { "$", "store", "book", 2, "category" }, value = "fiction" },
        { path = { "$", "store", "book", 2, "author" }, value = "Herman Melville" },
        { path = { "$", "store", "book", 2, "title" }, value = "Moby Dick" },
        { path = { "$", "store", "book", 2, "isbn" }, value = "0-553-21311-3" },
        { path = { "$", "store", "book", 2, "price" }, value = 8.99 },
        { path = { "$", "store", "book", 3, "category" }, value = "fiction" },
        { path = { "$", "store", "book", 3, "author" }, value = "J. R. R. Tolkien" },
        { path = { "$", "store", "book", 3, "title" }, value = "The Lord of the Rings" },
        { path = { "$", "store", "book", 3, "isbn" }, value = "0-395-19395-8" },
        { path = { "$", "store", "book", 3, "price" }, value = 22.99 },
        { path = { "$", "store", "bicycle", "color" }, value = "red" },
        { path = { "$", "store", "bicycle", "price" }, value = 19.95 },
      })
    )
  end,

  testAllElementsViaSubscriptWildcard = function()
    local results, err = jp.nodes(store, "$..[*]")
    lu.assertNil(err)
    lu.assertItemsEquals(results, jp.nodes(store, "$..*"))
  end,

  testObjectSubscriptWildcard = function()
    local results, err = jp.query(store, "$.store[*]")
    lu.assertNil(err)
    lu.assertItemsEquals(results, { store.store.book, store.store.bicycle })
  end,

  testNoMatchReturnsEmptyArray = function()
    local results, err = jp.nodes(store, "$..bookz")
    lu.assertNil(err)
    lu.assertItemsEquals(results, {})
  end,

  testMemberNumericLiteralGetsFirstElement = function()
    local results, err = jp.nodes(store, "$.store.book.0")
    lu.assertNil(err)
    lu.assertItemsEquals(results, {
      { path = { "$", "store", "book", 0 }, value = store.store.book[1] },
    })
  end,

  testDescendantNumericLiteralGetsFirstElement = function()
    local results, err = jp.nodes(store, "$.store.book..0")
    lu.assertNil(err)
    lu.assertItemsEquals(results, {
      { path = { "$", "store", "book", 0 }, value = store.store.book[1] },
    })
  end,

  testRootElementGetsUsOriginalObj = function()
    local results, err = jp.nodes(store, "$")
    lu.assertNil(err)
    lu.assertItemsEquals(results, {
      { path = { "$" }, value = store },
    })
  end,

  test_SubscriptDoubleQuotedString = function()
    local results, err = jp.nodes(store, '$["store"]')
    lu.assertNil(err)
    lu.assertItemsEquals(results, {
      { path = { "$", "store" }, value = store.store },
    })
  end,

  testSubscriptSingleQuotedString = function()
    local results, err = jp.nodes(store, "$['store']")
    lu.assertNil(err)
    lu.assertItemsEquals(results, {
      { path = { "$", "store" }, value = store.store },
    })
  end,

  testLeadingMemberComponent = function()
    local results, err = jp.nodes(store, "store")
    lu.assertNil(err)
    lu.assertItemsEquals(results, {
      { path = { "$", "store" }, value = store.store },
    })
  end,

  testUnionOfThreeArraySlices = function()
    local results, err = jp.query(store, "$.store.book[0:1,1:2,2:3]")
    lu.assertNil(err)
    lu.assertItemsEquals(results, {
      store.store.book[1],
      store.store.book[2],
      store.store.book[3],
    })
  end,

  testSliceWithStepGreaterThan1 = function()
    local results, err = jp.query(store, "$.store.book[0:4:2]")
    lu.assertNil(err)
    lu.assertItemsEquals(results, {
      store.store.book[1],
      store.store.book[3],
    })
  end,

  testSliceLastSlice = function()
    local results, err = jp.query(store, "$.store.book[-1:]")
    lu.assertNil(err)
    lu.assertItemsEquals(results, {
      store.store.book[4],
    })
  end,

  testSliceLastTwoSlices = function()
    local results, err = jp.query(store, "$.store.book[-2:]")
    lu.assertNil(err)
    lu.assertItemsEquals(results, {
      store.store.book[3],
      store.store.book[4],
    })
  end,

  testSliceSecondToLastSlice = function()
    local results, err = jp.query(store, "$.store.book[-2:-1]")
    lu.assertNil(err)
    lu.assertItemsEquals(results, {
      store.store.book[3],
    })
  end,

  testUnionOfSubscriptStringLiteralKeys = function()
    local results, err = jp.nodes(store, "$.store['book','bicycle']")
    lu.assertNil(err)
    lu.assertItemsEquals(
      results,
      sortByPath({
        { path = { "$", "store", "book" }, value = store.store.book },
        { path = { "$", "store", "bicycle" }, value = store.store.bicycle },
      })
    )
  end,

  testUnionOfSubscriptStringLiteralThreeKeys = function()
    local results, err = jp.nodes(store, "$.store.book[0]['title','author','price']")
    lu.assertNil(err)
    lu.assertItemsEquals(
      results,
      sortByPath({
        { path = { "$", "store", "book", 0, "title" }, value = store.store.book[1].title },
        { path = { "$", "store", "book", 0, "author" }, value = store.store.book[1].author },
        { path = { "$", "store", "book", 0, "price" }, value = store.store.book[1].price },
      })
    )
  end,

  testUnionOfSubscriptIntegerThreeKeysFollowedByMemberChildIdentifier = function()
    local results, err = jp.nodes(store, "$.store.book[1,2,3]['title']")
    lu.assertNil(err)
    lu.assertItemsEquals(
      results,
      sortByPath({
        { path = { "$", "store", "book", 1, "title" }, value = store.store.book[2].title },
        { path = { "$", "store", "book", 2, "title" }, value = store.store.book[3].title },
        { path = { "$", "store", "book", 3, "title" }, value = store.store.book[4].title },
      })
    )
  end,

  testUnionOfSubscriptIntegerThreeKeysFollowedByUnionOfSubscriptStringLiteralThreeKeys = function()
    local results, err = jp.nodes(store, "$.store.book[0,1,2,3]['title','author','price']")
    lu.assertNil(err)
    lu.assertItemsEquals(
      results,
      sortByPath({
        { path = { "$", "store", "book", 0, "title" }, value = store.store.book[1].title },
        { path = { "$", "store", "book", 0, "author" }, value = store.store.book[1].author },
        { path = { "$", "store", "book", 0, "price" }, value = store.store.book[1].price },
        { path = { "$", "store", "book", 1, "title" }, value = store.store.book[2].title },
        { path = { "$", "store", "book", 1, "author" }, value = store.store.book[2].author },
        { path = { "$", "store", "book", 1, "price" }, value = store.store.book[2].price },
        { path = { "$", "store", "book", 2, "title" }, value = store.store.book[3].title },
        { path = { "$", "store", "book", 2, "author" }, value = store.store.book[3].author },
        { path = { "$", "store", "book", 2, "price" }, value = store.store.book[3].price },
        { path = { "$", "store", "book", 3, "title" }, value = store.store.book[4].title },
        { path = { "$", "store", "book", 3, "author" }, value = store.store.book[4].author },
        { path = { "$", "store", "book", 3, "price" }, value = store.store.book[4].price },
      })
    )
  end,

  testUnionOfSubscript4ArraySlicesFollowedByUnionOfSubscriptStringLiteralThreeKeys = function()
    local results, err = jp.nodes(store, "$.store.book[0:1,1:2,2:3,3:4]['title','author','price']")
    lu.assertNil(err)
    lu.assertItemsEquals(
      results,
      sortByPath({
        { path = { "$", "store", "book", 0, "title" }, value = store.store.book[1].title },
        { path = { "$", "store", "book", 0, "author" }, value = store.store.book[1].author },
        { path = { "$", "store", "book", 0, "price" }, value = store.store.book[1].price },
        { path = { "$", "store", "book", 1, "title" }, value = store.store.book[2].title },
        { path = { "$", "store", "book", 1, "author" }, value = store.store.book[2].author },
        { path = { "$", "store", "book", 1, "price" }, value = store.store.book[2].price },
        { path = { "$", "store", "book", 2, "title" }, value = store.store.book[3].title },
        { path = { "$", "store", "book", 2, "author" }, value = store.store.book[3].author },
        { path = { "$", "store", "book", 2, "price" }, value = store.store.book[3].price },
        { path = { "$", "store", "book", 3, "title" }, value = store.store.book[4].title },
        { path = { "$", "store", "book", 3, "author" }, value = store.store.book[4].author },
        { path = { "$", "store", "book", 3, "price" }, value = store.store.book[4].price },
      })
    )
  end,

  testNestedParenthesesEval = function()
    local pathExpression = "$..book[?( @.price && (@.price + 20 || false) )]"
    local results, err = jp.query(store, pathExpression)
    lu.assertNil(err)
    lu.assertItemsEquals(results, store.store.book)
  end,

  testArrayIndicesFrom0To100 = function()
    local store = {}
    for i = 1, 100 do
      store[i] = math.random()
    end
    for i = 1, 100 do
      local results, err = jp.query(store, "$[" .. tostring(i - 1) .. "]")
      lu.assertNil(err)
      lu.assertItemsEquals(results, { store[i] })
    end
  end,

  testDescendantSubscriptNumericLiteral1 = function()
    local store = { 0, { 1, 2, 3 }, { 4, 5, 6 } }
    local results, err = jp.query(store, "$..[0]")
    lu.assertNil(err)
    lu.assertItemsEquals(results, { 0, 1, 4 })
  end,

  testDescendantSubscriptNumericLiteral2 = function()
    local store = { 0, 1, { 2, 3, 4 }, { 5, 6, 7, { 8, 9, 10 } } }
    local results, err = jp.query(store, "$..[0,1]")
    lu.assertNil(err)
    lu.assertItemsEquals(results, { 0, 1, 2, 3, 5, 6, 8, 9 })
  end,

  testThrowsForNoInput = function()
    local result, err = jp.query()
    lu.assertNil(result)
    lu.assertNotNil(err)
  end,

  testThrowsForBadInput1 = function()
    local result, err = jp.query("string", "string")
    lu.assertNil(result)
    lu.assertNotNil(err)
  end,

  testThrowsForBadInput2 = function()
    local result, err = jp.query({}, nil)
    lu.assertNil(result)
    lu.assertNotNil(err)
  end,

  testThrowsForBadInput3 = function()
    local result, err = jp.query({}, 42)
    lu.assertNil(result)
    lu.assertNotNil(err)
  end,
}

testLessons = {
  testCommaInEval = function()
    local path = "$..book[?(@.price && ',')]"
    local results, err = jp.query(store, path)
    lu.assertNil(err)
    lu.assertItemsEquals(results, store.store.book)
  end,

  testMemberNamesWithDots = function()
    local store = { ["www.google.com"] = 42, ["www.wikipedia.org"] = 190 }
    local results, err = jp.query(store, "$['www.google.com']")
    lu.assertNil(err)
    lu.assertItemsEquals(results, { 42 })
  end,

  testNestedObjectsWithFilter = function()
    local store = {
      dataResult = {
        object = {
          objectInfo = {
            className = "folder",
            typeName = "Standard Folder",
            id = "uniqueId",
          },
        },
      },
    }
    local results, err = jp.query(store, "$..object[?(@.className=='folder')]")
    lu.assertNil(err)
    lu.assertItemsEquals(results, {
      store.dataResult.object.objectInfo,
    })
  end,

  testScriptExpressionsWithAtChar = function()
    local store = {
      DIV = { {
        ["@class"] = "value",
        val = 5,
      } },
    }
    local results, err = jp.query(store, "$..DIV[?(@['@class']=='value')]")
    lu.assertNil(err)
    lu.assertItemsEquals(results, store.DIV)
  end,
}

testSugar = {
  testValueMethodGetsUsAValue = function()
    local store = { a = 1, b = 2, c = 3, z = { a = 100, b = 200 } }
    local b, err = jp.value(store, "$..b")
    lu.assertNil(err)
    lu.assertItemsEquals(b, store.b)
  end,
}

testGrammer = {

  testGrammerNodes = function()
    local assignment = lpeg.C(lpeg.R("az")) * lpeg.P("=") * lpeg.P('"') * jp.grammer() * lpeg.P('"')
    local var, ast = assignment:match('x="$..author"')
    lu.assertItemsEquals(var, "x")
    lu.assertItemsEquals(ast, { "$", "..", "author" })
    local results, err = jp.nodes(store, ast)
    lu.assertNil(err)
    lu.assertItemsEquals(results, {
      { path = { "$", "store", "book", 0, "author" }, value = "Nigel Rees" },
      { path = { "$", "store", "book", 1, "author" }, value = "Evelyn Waugh" },
      { path = { "$", "store", "book", 2, "author" }, value = "Herman Melville" },
      { path = { "$", "store", "book", 3, "author" }, value = "J. R. R. Tolkien" },
    })
  end,

  testGrammerQuery = function()
    local assignment = lpeg.C(lpeg.R("az")) * lpeg.P("=") * lpeg.P('"') * jp.grammer() * lpeg.P('"')
    local var, ast = assignment:match('x="$..author"')
    lu.assertItemsEquals(var, "x")
    lu.assertItemsEquals(ast, { "$", "..", "author" })
    local results, err = jp.query(store, ast)
    lu.assertNil(err)
    lu.assertItemsEquals(results, {
      "Nigel Rees",
      "Evelyn Waugh",
      "Herman Melville",
      "J. R. R. Tolkien",
    })
  end,
}

testDocumentation = {

  testReadmeIntroductoryExample = function()
    local cities = {
      { name = "London", population = 8615246 },
      { name = "Berlin", population = 3517424 },
      { name = "Madrid", population = 3165235 },
      { name = "Rome", population = 2870528 },
    }
    local names, err = jp.query(cities, "$..name")
    lu.assertNil(err)
    lu.assertItemsEquals(names, { "London", "Berlin", "Madrid", "Rome" })
  end,

  testReadmeExpressionsTheAuthorsOfAllBooksInTheStore = function()
    testQuery.testAuthorsOfAllBooksInTheStore()
  end,

  testReadmeExpressionsAllAuthors = function()
    testQuery.testAllAuthors()
  end,

  testReadmeExpressionsAllThingsInStore = function()
    testQuery.testAllThingsInStore()
  end,

  testReadmeExpressionsThePriceOfEverythingInTheStore = function()
    testQuery.testPriceOfEverythingInTheStore()
  end,

  testReadmeExpressionsTheThirdBookViaArraySubscript = function()
    local results, err = jp.nodes(store, "$..book[2]")
    lu.assertNil(err)
    lu.assertItemsEquals(
      results,
      sortByPath({
        { path = { "$", "store", "book", 2 }, value = store.store.book[3] },
      })
    )
  end,

  testReadmeExpressionsTheThirdBookViaScriptSubscript = function()
    testQuery.testLastBookInOrderViaExpression()
  end,

  testReadmeExpressionsTheLastBookInOrder = function()
    local results, err = jp.nodes(store, "$..book[-1:]")
    lu.assertNil(err)
    lu.assertItemsEquals(
      results,
      sortByPath({
        { path = { "$", "store", "book", 3 }, value = store.store.book[4] },
      })
    )
  end,

  testReadmeExpressionsTheLastTwoBooksInOrder = function()
    local results, err = jp.nodes(store, "$..book[-2:]")
    lu.assertNil(err)
    lu.assertItemsEquals(
      results,
      sortByPath({
        { path = { "$", "store", "book", 2 }, value = store.store.book[3] },
        { path = { "$", "store", "book", 3 }, value = store.store.book[4] },
      })
    )
  end,

  testReadmeExpressionsTheSecondToLastBookInOrder = function()
    local results, err = jp.nodes(store, "$..book[-2:-1]")
    lu.assertNil(err)
    lu.assertItemsEquals(
      results,
      sortByPath({
        { path = { "$", "store", "book", 2 }, value = store.store.book[3] },
      })
    )
  end,

  testReadmeExpressionsTheFirstTwoBooksViaSubscriptUnion = function()
    testQuery.testFirstTwoBooksViaUnion()
  end,

  testReadmeExpressionsTheFirstTwoBooksViaSubscriptArraySlice = function()
    local results, err = jp.nodes(store, "$..book[:2]")
    lu.assertNil(err)
    lu.assertItemsEquals(
      results,
      sortByPath({
        { path = { "$", "store", "book", 0 }, value = store.store.book[1] },
        { path = { "$", "store", "book", 1 }, value = store.store.book[2] },
      })
    )
  end,

  testReadmeExpressionsFilterAllBooksWithIsbnNumber = function()
    testQuery.testFilterAllBooksWithIsbnNumber()
  end,

  testReadmeExpressionsFilterAllBooksCheaperThan10 = function()
    testQuery.testFilterAllBooksWithAPriceLessThan10()
  end,

  testReadmeExpressionsFilterAllBooksThatCost8P95 = function()
    local results, err = jp.nodes(store, "$..book[?(@.price==8.95)]")
    lu.assertNil(err)
    lu.assertItemsEquals(results, {
      { path = { "$", "store", "book", 0 }, value = store.store.book[1] },
    })
  end,

  testReadmeExpressionsFilterAllStoreBooksThatCost8P95Title = function()
    local results, err = jp.nodes(store, "$.store.book[?(@.price==8.95)].title")
    lu.assertNil(err)
    lu.assertItemsEquals(results, {
      { path = { "$", "store", "book", 0, "title" }, value = "Sayings of the Century" },
    })
  end,

  testReadmeExpressionsFilterAllBooksThatCost8P95Title = function()
    local results, err = jp.nodes(store, "$..book[?(@.price==8.95)].title")
    lu.assertNil(err)
    lu.assertItemsEquals(results, {
      { path = { "$", "store", "book", 0, "title" }, value = "Sayings of the Century" },
    })
  end,

  testReadmeExpressionsFilterAllFictionBooksCheaperThan30 = function()
    local results, err = jp.nodes(store, '$..book[?(@.price<30 && @.category=="fiction")]')
    lu.assertNil(err)
    lu.assertItemsEquals(results, {
      { path = { "$", "store", "book", 1 }, value = store.store.book[2] },
      { path = { "$", "store", "book", 2 }, value = store.store.book[3] },
      { path = { "$", "store", "book", 3 }, value = store.store.book[4] },
    })
  end,

  testReadmeExpressionsAllMembersOfLuaStructure = function()
    testQuery.testAllElements()
  end,

  testReadmeQueryExample = function()
    local author, err = jp.query(store, "$..author")
    lu.assertNil(err)
    lu.assertItemsEquals(author, { "Nigel Rees", "Evelyn Waugh", "Herman Melville", "J. R. R. Tolkien" })
  end,

  testReadmeValueExample = function()
    local author, err = jp.value(store, "$..author")
    lu.assertNil(err)
    lu.assertItemsEquals(author, "Nigel Rees")
  end,

  testReadmePathsExample = function()
    local author, err = jp.paths(store, "$..author")
    lu.assertNil(err)
    lu.assertItemsEquals(author, {
      { "$", "store", "book", 0, "author" },
      { "$", "store", "book", 1, "author" },
      { "$", "store", "book", 2, "author" },
      { "$", "store", "book", 3, "author" },
    })
  end,

  testReadmeEmploeeByName = function()
    local employee, err = jp.nodes(employees, '$[?(@.name == "Tom")]')
    lu.assertNil(err)
    lu.assertItemsEquals(employee, {
      { path = { "$", 0 }, value = { name = "Tom" } },
    })
  end,

  testReadmeEmploeeNameByName = function()
    local employee, err = jp.nodes(employees, '$[?(@.name == "Tom")].name')
    lu.assertNil(err)
    lu.assertItemsEquals(employee, {
      { path = { "$", 0, "name" }, value = "Tom" },
    })
  end,

  testReadmeNodesExample = function()
    testQuery.testAllAuthors()
  end,

  testReadmeParseExample = function()
    testParse.testParsePathForAllAuthors()
  end,

  testReadmeGrammerExample = function()
    testGrammer.testGrammerQuery()
  end,
}

-- Run test suites
os.exit(lu.LuaUnit.run())
