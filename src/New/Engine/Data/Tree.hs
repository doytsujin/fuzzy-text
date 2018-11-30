{-# LANGUAGE Strict #-}
module New.Engine.Data.Tree
    ( module New.Engine.Data.Tree
    , module X
    ) where

import New.Engine.Data.Index as X (HasIndex (index))

import Prologue hiding (Index, lookup)

import qualified Control.Monad.State.Layered as State
import qualified Data.Map.Strict             as Map
import qualified Data.Text                   as Text
import qualified New.Engine.Data.Index       as Index

import Control.Lens          (Getter, to, (?~), _Just)
import Data.Map.Strict       (Map)
import New.Engine.Data.Index (Index (Index), IndexMap)



------------------
-- === Node === --
------------------


-- === Definition === --

data Node = Node
    { __index   :: Index
    , _branches :: Map Char Node
    } deriving (Eq, Generic, Show)
makeLenses ''Node

instance Default  Node where def   = Node def def
instance HasIndex Node where index = node_index
instance NFData   Node



------------------
-- === Tree === --
------------------


-- === Definition === --

data Tree = Tree
    { _root     :: Node
    , _indexMap :: IndexMap
    } deriving (Eq, Generic, Show)
makeLenses ''Tree

instance Default Tree where def = Tree def def
instance NFData  Tree

nextIndex :: Getter Tree Index
nextIndex = to $! \tree -> Index $! tree ^. indexMap . to Map.size
{-# INLINE nextIndex #-}


-- === API === --

mk :: [Text] -> Tree
mk txts = insertMultiple txts def
{-# INLINE mk #-}

singleton :: Text -> Tree
singleton txt = insert txt def
{-# INLINE singleton #-}

insert :: Text -> Tree -> Tree
insert txt tree = let
    root'         = tree ^. root
    idxMap        = tree ^. indexMap
    insertToNode' = insertToNode txt txt root'
    (updatedRoot, updatedMap) = State.run @IndexMap insertToNode' idxMap
    in tree
        & root     .~ updatedRoot
        & indexMap .~ updatedMap
{-# INLINE insert #-}

insertToNode :: State.Monad IndexMap m => Text -> Text -> Node -> m Node
insertToNode suffix txt node = case Text.uncons suffix of
    Nothing           -> updateValue txt node
    Just ((!h), (!t)) -> do
        let mayNextBranch = node ^. branches . at h
            nextBranch    = fromJust def mayNextBranch
        branch <- insertToNode t txt nextBranch
        pure $! node & branches . at h ?~ branch

{-# INLINE insertToNode #-}


updateValue :: State.Monad IndexMap m => Text -> Node -> m Node
updateValue k node = let
    idx       = node ^. index
    updateMap = do
        newIndex <- Index.get
        State.modify_ @IndexMap $! Map.insert k newIndex
        pure $! node & index .~ newIndex
    in if Index.isInvalid idx then updateMap else pure node
{-# INLINE updateValue #-}

insertMultiple :: [Text] -> Tree -> Tree
insertMultiple txts tree = foldl (flip insert) tree txts where
{-# INLINE insertMultiple #-}

lookup :: Text -> Tree -> Maybe Node
lookup txt tree = lookupNode txt root' where
    root' = tree ^. root
{-# INLINE lookup #-}

lookupNode :: Text -> Node -> Maybe Node
lookupNode txt n = case Text.uncons txt of
    Nothing       -> Just n
    Just (!h, !t) -> n ^? branches . at h . _Just . to (lookupNode t) . _Just
{-# INLINE lookupNode #-}
