{-# LANGUAGE QuasiQuotes #-}
module Main where

import           Control.Monad                  ( when )
import           System.Environment             ( getArgs )
import           System.Console.Docopt
import qualified Data.ByteString.Char8         as C
import qualified Data.ByteString.Base16        as H
import           Crypto.Longshot.Internal
import           Crypto.Longshot.Hasher         ( getHasher )

patterns :: Docopt
patterns = [docopt|
longshot - Fast Brute-force search using parallelism

Usage:
  longshot run        [--deep | -n SIZE] [-c CHARS] [-a HASHER] HEX
  longshot image      [-a HASHER] KEY

Commands:
  run                 Brute-force search with given hexstring and options
  image               Generate image from given key string and hash algorithm

Arguments:
  HEX                 Specify target hexstring to search
  KEY                 Specify key string as a preimage

Options:
  -h --help           Show this
  --deep              Deep search by increasing length of search
                      Use when you do not know the exact length of preimage
  -n SIZE             Specify search length  [default: 8]   
  -c CHARS            Specify characters in preimage  [default: 0123456789]
  -a HASHER           Specify hash algorithm  [default: sha256]
                      HASHER available below:
                      md5           sha1          ripemd160     whirlpool
                      sha256        sha3_256      sha3_384      sha3_512
                      blake2s_256   blake2b_256   blake2b_384   blake2b_512
                      blake3_256    blake3_384    blake3_512
                      keccak_256    keccak_384    keccak_512
                      skein_256     skein_384     skein_512
|]

-- | Defines args-ops frequently used
(><) = isPresent
(<->|!) = getArgOrExitWith patterns
(<->) = getArg

main :: IO ()
main = do
  args <- parseArgsOrExit patterns =<< getArgs
  when (args >< command "image") $ genImage args
  when (args >< command "run") $ run args

-- | Command: image
genImage :: Arguments -> IO ()
genImage args = do
  key    <- C.pack <$> (args <->|! argument "KEY")
  hasher <- getHasher <$> (args <->|! shortOption 'a')
  putStrLn . C.unpack . H.encode . hasher $ key

-- | Command: run
run :: Arguments -> IO ()
run args = do
  hex    <- args <->|! argument "HEX"
  chars  <- args <->|! shortOption 'c'
  size   <- (read <$> (args <->|! shortOption 'n')) :: IO Int
  hasher <- getHasher <$> (args <->|! shortOption 'a')
  let solver | args >< longOption "deep" = bruteforceDeep
             | otherwise                 = bruteforce size
  let found = solver chars hex hasher
  case found of
    Just key -> putStrLn $ "Found  " <> key
    _        -> putStrLn "Not found"
