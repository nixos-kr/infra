module MessageLink (MessageRef(..), parseMessageLink) where

import Data.Text (Text)
import qualified Data.Text as T

data MessageRef = MessageRef
  { refGuildId   :: Text
  , refChannelId :: Text
  , refMessageId :: Text
  } deriving (Eq, Show)

-- | Parse a Discord message URL into guild/channel/message IDs.
-- Accepts: https://discord.com/channels/{guild}/{channel}/{message}
--          https://canary.discord.com/channels/{guild}/{channel}/{message}
--          https://ptb.discord.com/channels/{guild}/{channel}/{message}
parseMessageLink :: Text -> Maybe MessageRef
parseMessageLink url =
  case T.splitOn "/channels/" stripped of
    [_, rest] ->
      case T.splitOn "/" rest of
        [gid, cid, mid]
          | not (T.null gid) && not (T.null cid) && not (T.null mid) ->
            Just (MessageRef gid cid mid)
        _ -> Nothing
    _ -> Nothing
  where
    stripped = T.replace "canary." "" . T.replace "ptb." "" $ url
