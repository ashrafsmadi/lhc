{-# LANGUAGE MagicHash, ForeignFunctionInterface #-}
{-# LANGUAGE UnboxedTuples #-}
module LHC.Prim
    ( IO
    , Unit(Unit)
    , I8
    , I32
    , I64
    , Addr
    , bindIO
    , thenIO
    , return
    , unsafePerformIO
    , List(Nil,Cons)
    -- , sequence_
    , getArgs
    , unpackString#
    , putStr
    , putStrLn
    , getChar
    , getLine
    , Char(C#)
    , Bool(True,False)
    , Int(I#)
    , not
    , otherwise
    , (+), (-), (*)
    , (-#)
    , sum
    , shiftL
    -- , udiv, urem
    , sdiv, srem
    , mapM_
    , (<=), le#
    , max
    , i32toi64
    , i64toi32
    , length
    , emptyString
    , id
    ) where

-- XXX: These have kind # but it is not checked anywhere.
--      Use them incorrectly and the world will explode.
data I8
data I32
data I64
data Addr a
data Ptr a = Ptr (Addr a)

data Int32 = Int32 I32

data Int = I# I32

data Char = C# I32

data RealWorld#

foreign import ccall realworld# :: RealWorld#

-- data IOUnit a = IOUnit a RealWorld
--newtype IO a = IO { unIO :: RealWorld -> IOUnit a }
newtype IO a = IO (RealWorld# -> (# RealWorld#, a #))

data Unit = Unit
data List a = Nil | Cons a (List a)

unIO :: IO a -> RealWorld# -> (# RealWorld#, a #)
unIO action =
  case action of
    IO unit -> unit

bindIO :: IO a -> (a -> IO b) -> IO b
bindIO f g = IO (\s ->
  case unIO f s of
    (# s', a #) -> unIO (g a) s')

thenIO :: IO a -> IO b -> IO b
thenIO a b = bindIO a (\c -> b)

-- infixl 1 `thenIO`

return :: a -> IO a
return a = IO (\s -> (# s, a #))

unsafePerformIO :: IO a -> a
unsafePerformIO action =
  case unIO action realworld# of
    (# st, val #) -> val

foreign import ccall unsafe "putchar" c_putchar :: I32 -> IO Int32

-- sequence_ :: List (IO Unit) -> IO Unit
-- sequence_ lst =
--   case lst of
--     Nil -> return Unit
--     Cons head tail -> thenIO head (sequence_ tail)

foreign import ccall unsafe indexI8# :: Addr I8 -> I8
foreign import ccall addrAdd# :: Addr I8 -> I64 -> Addr I8
foreign import ccall "cast" i64toi32 :: I64 -> I32
foreign import ccall "cast" i8toi64 :: I8 -> I64
foreign import ccall "cast" i8toi32 :: I8 -> I32
foreign import ccall "cast" i32toi64 :: I32 -> I64

unpackString# :: Addr I8 -> [Char]
unpackString# ptr =
  case i8toi64 (indexI8# ptr) of
    0#   -> []
    char -> (:) (C# (i64toi32 char)) (unpackString# (addrAdd# ptr 1#))

foreign import ccall unsafe "_lhc_getargc" c_getargc :: IO Int32
foreign import ccall unsafe "_lhc_getargv" c_getargv :: I32 -> IO (Ptr I8)

getArgs :: IO [[Char]]
getArgs = do
  argc <- c_getargc
  case argc of
    Int32 n -> getArgs_worker [] n

getArgs_worker :: [[Char]] -> I32 -> IO [[Char]]
getArgs_worker acc '\0'# = return acc
getArgs_worker acc n = do
  ptr <- c_getargv (n -# '\1'#)
  case ptr of
    Ptr str -> getArgs_worker (unpackString# str : acc) (n -# '\1'#)

foreign import ccall "getchar" c_getchar :: IO Int32

getChar :: IO Char
getChar =
  c_getchar `bindIO` \c ->
  case c of
    Int32 c# -> return (C# c#)

getLine :: IO [Char]
getLine =
  getChar `bindIO` \c ->
  case c of
    C# c# ->
      case c# of
        '\n'# -> return []
        _     -> getLine `bindIO` \cs -> return (c : cs)

putStr :: [Char] -> IO ()
putStr lst =
  case lst of
    [] -> return ()
    head : tail ->
      case head of
        C# char ->
          c_putchar char `thenIO` putStr tail

putStrLn :: [Char] -> IO ()
putStrLn msg = putStr msg `thenIO` putStr (unpackString# "\n"#)

data Bool = False | True

not :: Bool -> Bool
not False = True
not True  = False

otherwise :: Bool
otherwise = True

foreign import ccall unsafe (+#) :: I32 -> I32 -> I32

foreign import ccall unsafe (-#) :: I32 -> I32 -> I32

foreign import ccall unsafe (*#) :: I32 -> I32 -> I32

(+) :: Int -> Int -> Int
I# a# + I# b# = I# (a# +# b#)

(-) :: Int -> Int -> Int
I# a# - I# b# = I# (a# -# b#)

(*) :: Int -> Int -> Int
I# a# * I# b# = I# (a# *# b#)

foreign import ccall unsafe udiv# :: I32 -> I32 -> I32
foreign import ccall unsafe sdiv# :: I32 -> I32 -> I32

foreign import ccall unsafe urem# :: I32 -> I32 -> I32
foreign import ccall unsafe srem# :: I32 -> I32 -> I32

foreign import ccall unsafe shl# :: I32 -> I32 -> I32

shiftL :: Int -> Int -> Int
shiftL (I# a#) (I# b#) = I# (shl# a# b#)

-- udiv :: Int -> Int -> Int
-- udiv (I# a#) (I# b#) = I# (udiv# a# b#)

sdiv :: Int -> Int -> Int
sdiv (I# a#) (I# b#) = I# (sdiv# a# b#)

-- urem :: Int -> Int -> Int
-- urem (I# a#) (I# b#) = I# (urem# a# b#)

srem :: Int -> Int -> Int
srem (I# a#) (I# b#) = I# (srem# a# b#)

--seq :: a -> b -> b
--seq a b = b

--bit :: Int -> Int
--bit = bit
-- bit n = 1<<n

mapM_ :: (a -> IO ()) -> [a] -> IO ()
mapM_ fn lst =
  case lst of
    [] -> return ()
    (:) x xs -> fn x `thenIO` mapM_ fn xs

foreign import ccall unsafe le# :: I32 -> I32 -> I32

-- <=
(<=) :: Int -> Int -> Bool
I# a# <= I# b# =
  case le# a# b# of
    '\0'# -> False
    _     -> True

max :: Int -> Int -> Int
max a b =
  case a <= b of
    True -> b
    False -> a


length :: [a] -> Int
length lst = length_go '\0'# lst

length_go :: I32 -> [a] -> Int
length_go n [] = I# n
length_go n (x:xs) = length_go (n +# '\1'#) xs

sum :: [Int] -> Int
sum lst = sum_go '\0'# lst

sum_go :: I32 -> [Int] -> Int
sum_go n [] = I# n
sum_go n (I# x:xs) = sum_go (n +# x) xs

emptyString :: [Char]
emptyString = []

id :: a -> a
id x = x
