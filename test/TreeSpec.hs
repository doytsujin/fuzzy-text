module TreeSpec (spec) where

import Prologue   hiding (Index)
import Test.Hspec

import qualified Data.Map.Strict             as Map
import qualified Data.Text                   as Text
import qualified New.Engine.Data.Tree        as Tree

import Control.Exception     (throw)
import Control.Lens          (makePrisms)
import Data.Set              (Set)
import Data.Map.Strict              (Map)
import New.Engine.Data.Index (Index, TextMap)
import New.Engine.Data.Tree  (Tree (Tree), Node (Node), branches, index)


data TreeStructureExceptionType
    = IncorrectIndex    Index      Index
    | IncorrectBranches (Set Char) (Set Char)
    deriving (Eq, Generic, Show, Typeable)

data TreeStructureException = TreeStructureException
    { _dictionaryKey :: Text
    , _exceptionType :: TreeStructureExceptionType
    } deriving (Eq, Generic, Show, Typeable)

makeLenses ''TreeStructureException
makePrisms ''TreeStructureExceptionType

instance Exception TreeStructureException


recursiveCheckTreeStructure :: Text -> Map Text Index -> Node -> IO ()
recursiveCheckTreeStructure matchedPrefix indexMap dict = check where
    accFunction acc k v = if Text.null k
        then acc
        else Map.insertWith
            Map.union
            (Text.head k)
            (Map.singleton (Text.drop 1 k) v)
            acc
    slicedMap = Map.foldlWithKey accFunction mempty indexMap
    currentIndex = fromJust def $ Map.lookup mempty indexMap
    checkForException :: (Eq a, Show a, Typeable a)
        => (a -> a -> TreeStructureExceptionType) -> a -> a -> IO ()
    checkForException tpe a b = when (a /= b) $ throw
        $ TreeStructureException matchedPrefix $ tpe a b
    check   = do
        checkForException IncorrectIndex currentIndex $ dict ^. index
        checkForException
            IncorrectBranches
            (Map.keysSet slicedMap)
            (Map.keysSet $ dict ^. branches)
        for_ (toList slicedMap) $ \(c, newTextMap) ->
            for_ (dict ^. branches . at c) $ recursiveCheckTreeStructure
                (Text.snoc matchedPrefix c)
                newTextMap

checkTreeStructure :: Tree -> IO ()
checkTreeStructure tree = catch check handleException where
    textMap  = tree ^. Tree.textMap
    indexMap = fromList . fmap swap $ toList textMap
    root     = tree ^. Tree.root
    check    = recursiveCheckTreeStructure mempty indexMap root
    handleException :: TreeStructureException -> IO ()
    handleException e =
        let k = e ^. dictionaryKey
            expectEq :: (Eq a, Show a) => a -> a -> IO ()
            expectEq m d = (k, m) `shouldBe` (k, d)
        in case e ^. exceptionType of
            IncorrectBranches m d -> expectEq m d
            IncorrectIndex    m d -> expectEq m d


dictionaryStructureExceptionSelector :: Selector TreeStructureException
dictionaryStructureExceptionSelector = const True

spec :: Spec
spec = do
    describe "tree structure check tests" $ do
        it "works on empty tree" $ checkTreeStructure def
        it "works with single letter" $ checkTreeStructure $ Tree
            (Node def $ Map.singleton 'a' $ Node 0 mempty)
            (Map.singleton 0 "a")
        it "works with branched data" $ checkTreeStructure $ flip Tree
            (fromList [(0, "aa"), (1, "ab")])
            $ Node def $ Map.singleton
                'a' $ Node def $ fromList
                    [ ('a', Node 0 mempty)
                    , ('b', Node 1 mempty) ]
        it "throws exception when map empty and dict not empty" $ shouldThrow
            (recursiveCheckTreeStructure
                mempty
                mempty
                $ Node def $ Map.singleton 'a' $ Node 0 mempty)
            dictionaryStructureExceptionSelector
        it "throws exception when map not empty and dict empty" $ shouldThrow
            (recursiveCheckTreeStructure mempty (Map.singleton "a" 0) def)
            dictionaryStructureExceptionSelector
        it "throws exception when map does not match dict" $ shouldThrow
            (recursiveCheckTreeStructure
                mempty
                (Map.singleton "ab" 0)
                $ Node def $ Map.singleton
                'a' $ Node def $ fromList
                    [ ('a', Node 0 mempty)
                    , ('b', Node 1 mempty) ])
            dictionaryStructureExceptionSelector
    describe "test insert function" $ do
        it "value is in map" $ let
            tree   = Tree.singleton "a"
            txtMap = tree ^. Tree.textMap
            in txtMap `shouldBe` Map.singleton 0 "a"
        it "value is in dictionary" $ let
            tree   = Tree.singleton "a"
            in checkTreeStructure tree
        it "values are in map" $ let
            tree = Tree.mk ["aa", "ab"]
            txtMap = tree ^. Tree.textMap
            in txtMap `shouldBe` fromList [(0, "aa"), (1, "ab")]
        it "values are in dictionary" $ checkTreeStructure $ Tree.mk ["aa", "ab"]
    describe "test insertMultiple function" $ do
        it "value is in map" $ let 
            tree   = Tree.singleton "a"
            txtMap = tree ^. Tree.textMap
            in txtMap `shouldBe` (Map.singleton 0 "a" )
        it "value is in dictionary" $ checkTreeStructure $ Tree.singleton "a"
        it "values are in map" $ let
            tree   = Tree.mk ["aa", "ab"]
            txtMap = tree ^. Tree.textMap 
            in txtMap `shouldBe` fromList [(0, "aa"), (1, "ab")]
        it "values are in dictionary" 
            $ checkTreeStructure $ Tree.mk ["aa", "ab"]
