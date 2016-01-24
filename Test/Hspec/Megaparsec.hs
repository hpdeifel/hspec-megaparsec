-- |
-- Module      :  Test.Hspec.Megaparsec
-- Copyright   :  © 2016 Mark Karpov
-- License     :  BSD 3 clause
--
-- Maintainer  :  Mark Karpov <markkarpov@openmailbox.org>
-- Stability   :  experimental
-- Portability :  portable
--
-- Utility functions for testing Megaparsec parsers with Hspec.

module Test.Hspec.Megaparsec
  ( -- * Basic expectations
    shouldParse
  , parseSatisfies
  , shouldSucceedOn
  , shouldFailOn
    -- * Testing of error messages
  , shouldFailWith
    -- * Incremental parsing
  , failsLeaving
  , succeedsLeaving
  , initialState )
where

import Control.Monad (unless)
import Test.Hspec.Expectations
import Text.Megaparsec
import Text.Megaparsec.Pos (initialPos, defaultTabWidth)

----------------------------------------------------------------------------
-- Basic expectations

-- | Create an expectation by saying what the result should be.
--
-- > parse letterChar "" "x" `shouldParse` 'x'

shouldParse :: (Eq a, Show a)
  => Either ParseError a
     -- ^ Result of parsing as returned by function like 'parse'
  -> a                 -- ^ Desired result
  -> Expectation
r `shouldParse` v = case r of
  Left e -> expectationFailure $ "expected: " ++ show v ++
    "\nbut parsing failed with error:\n" ++ showParseError e
  Right x -> unless (x == v) . expectationFailure $
    "expected: " ++ show v ++ "\nbut got: " ++ show x

-- | Create an expectation by saying that the parser should successfully
-- parse a value and that the value should satisfy some predicate.
--
-- > parse (many punctuationChar) "" "?!!" `parseSatisfies` ((== 3) . length)

parseSatisfies :: Show a
  => Either ParseError a
     -- ^ Result of parsing as returned by function like 'parse'
  -> (a -> Bool)       -- ^ Predicate
  -> Expectation
r `parseSatisfies` p = case r of
  Left e -> expectationFailure $
    "expected a parsed value to check against the predicate" ++
    "\nbut parsing failed with error:\n" ++ showParseError e
  Right x -> unless (p x) . expectationFailure $
    "the value did not satisfy the predicate: " ++ show x

-- | Check that a parser fails on some given input.
--
-- > parse (char 'x') "" `shouldFailOn` "a"

shouldFailOn :: (Show a, Stream s t)
  => (s -> Either ParseError a)
     -- ^ Parser that takes stream and produces result or error message
  -> s                 -- ^ Input that the parser should fail on
  -> Expectation
p `shouldFailOn` s = shouldFail (p s)

-- | Check that a parser succeeds on some given input.
--
-- > parse (char 'x') "" `shouldSucceedOn` "x"

shouldSucceedOn :: (Show a, Stream s t)
  => (s -> Either ParseError a)
     -- ^ Parser that takes stream and produces result or error message
  -> s                 -- ^ Input that the parser should succeed on
  -> Expectation
p `shouldSucceedOn` s = shouldSucceed (p s)

----------------------------------------------------------------------------
-- Testing of error messages

-- | Create an expectation that parser should fail producing certain
-- 'ParseError'. Use functions from "Text.Megaparsec.Error" to construct
-- parse errors to check against. See "Text.Megaparsec.Pos" for functions to
-- construct textual positions.
--
-- > parse (char 'x') "" "b" `shouldFailWith`
-- >   newErrorMessages [Unexpected "'b'", Expected "'x'"] (initialPos "")

shouldFailWith :: Show a
  => Either ParseError a
  -> ParseError
  -> Expectation
r `shouldFailWith` e = case r of
  Left e' -> unless (e == e') . expectationFailure $
    "the parser is expected to fail with:\n" ++ showParseError e ++
    "but it failed with:\n" ++ showParseError e
  Right v -> expectationFailure $
    "the parser is expected to fail, but it parsed: " ++ show v

----------------------------------------------------------------------------
-- Incremental parsing

-- | Check that a parser fails and leaves certain part of input
-- unconsumed. Use it with functions like 'runParser'' and 'runParserT''
-- that support incremental parsing.
--
-- > runParser' (many (char 'x') <* eof) (initialState "xxa")
-- >   `failsLeaving` "a"
--
-- See also: 'initialState'.

failsLeaving :: (Show a, Eq s, Show s, Stream s t)
  => (State s, Either ParseError a)
     -- ^ Parser that takes stream and produces result along with actual
     -- state information
  -> s                 -- ^ Part of input that should be left unconsumed
  -> Expectation
(st,r) `failsLeaving` s =
  shouldFail r >> checkUnconsumed s (stateInput st)

-- | Check that a parser succeeds and leaves certain part of input
-- unconsumed. Use it with functions like 'runParser'' and 'runParserT''
-- that support incremental parsing.
--
-- > runParser' (many (char 'x')) (initialState "xxa")
-- >   `succeedsLeaving` "a"
--
-- See also: 'initialState'.

succeedsLeaving :: (Show a, Eq s, Show s, Stream s t)
  => (State s, Either ParseError a)
     -- ^ Parser that takes stream and produces result along with actual
     -- state information
  -> s                 -- ^ Part of input that should be left unconsumed
  -> Expectation
(st,r) `succeedsLeaving` s =
  shouldSucceed r >> checkUnconsumed s (stateInput st)

-- | Given input for parsing, construct initial state for parser (that is,
-- with empty file name, default tab width and position at 1 line and 1
-- column).

initialState :: Stream s t => s -> State s
initialState s = State s (initialPos "") defaultTabWidth

----------------------------------------------------------------------------
-- Helpers

-- | Expectation that argument is result of a failed parser.

shouldFail :: Show a => Either ParseError a -> Expectation
shouldFail r = case r of
  Left _ -> return ()
  Right v -> expectationFailure $
    "the parser is expected to fail, but it parsed: " ++ show v

-- | Expectation that argument is result of a succeeded parser.

shouldSucceed :: Show a => Either ParseError a -> Expectation
shouldSucceed r = case r of
  Left e -> expectationFailure $
    "the parser is expected to succeed, but it failed with:\n" ++
    showParseError e
  Right _ -> return ()

-- | Compare two streams for equality and in the case of mismatch report it.

checkUnconsumed :: (Eq s, Show s, Stream s t)
  => s                 -- ^ Expected unconsumed input
  -> s                 -- ^ Actual unconsumed input
  -> Expectation
checkUnconsumed e a = unless (e == a) . expectationFailure $
  "the parser is expected to leave unconsumed input: " ++ show e ++
  "\nbut it left this: " ++ show a

-- | Render parse error in a way that is suitable for inserting it in test
-- suite report.

showParseError :: ParseError -> String
showParseError = unlines . fmap ("  " ++) . lines . show
