{-# LANGUAGE GeneralizedNewtypeDeriving #-}

module Network.Monitoring.RiemannT where

import Network.Monitoring.Riemann

import Data.Functor.Identity
import Control.Monad.IO.Class
import Control.Applicative

import Control.Proxy hiding (Client)

type Prx = ProxyFast

-- | A monad transformer layer which allows for the observation of
-- Riemann 'Event's.
newtype RiemannT m a =
  RiemannT (Prx () () () Event m a)
  deriving (Functor, Applicative, Monad, MonadTrans, MonadIO)

-- | This is written separately so that GeneralizedNewtypeDeriving can
-- do its magic.
unRiemannT :: RiemannT m a -> () -> Prx () () () Event m a
unRiemannT (RiemannT m) () = m

-- | A monad allowing the observation of Riemann 'Event's. Equivalent
-- to 'RiemannT Identity'.
type Riemann = RiemannT Identity

-- | Observes an 'Event' in the 'RiemannT' monad.
obs :: Monad m => Event -> RiemannT m ()
obs = RiemannT . runIdentityP . respond

-- | 'runRiemannT c' is for any 'MonadIO m' a natural transformation
-- from 'RiemannT m' to 'm', delivering the events raised in 'RiemannT
-- m' to the 'Client' 'c'.
runRiemannT :: MonadIO m => Client -> RiemannT m a -> m a
runRiemannT client rmt =
  runProxy (unRiemannT rmt >-> mapMD (liftIO . sendEvent client))

-- | Extracts the observed events from a 'Riemann' monad
observed :: Riemann a -> (a, [Event])
observed = runIdentity . observedT

-- | Extracts the observed events from a 'RiemannT' monad
--
-- If the monad below is 'IO' then this does not lazily produce
-- values; however, 'runRiemannT' does, so perhaps it has something to
-- do with the 'WriterT'.
observedT :: Monad m => RiemannT m a -> m (a, [Event])
observedT rmt = runWriterT $ runProxy (raiseK (unRiemannT rmt) >-> toListD)