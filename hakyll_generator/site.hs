
{-# LANGUAGE OverloadedStrings #-}
{-# OPTIONS_GHC -Wall #-}
import           Data.Monoid (mappend)
import           Hakyll
import           System.FilePath
import qualified System.Exit
import qualified System.Process  as Process
import           Text.Pandoc()

main :: IO ()
main = hakyll $ do
    match "images/*" $ do
        route   idRoute
        compile copyFileCompiler

    match "css/*" $ do
        route   idRoute
        compile compressCssCompiler

    match (fromList ["about.rst"
                    , "contact.markdown"
                    , "cv_ru.markdown"]) $ do
        route   $ setExtension "html"
        compile $ pandocCompiler
            >>= loadAndApplyTemplate "templates/default.html" defaultContext
            >>= relativizeUrls

    -- CV as PDF
    match "cv_ru.markdown" $ version "pdf" $ do
        route   $ setExtension ".pdf"
        compile $ do getResourceBody >>= xelatex

    match "posts/*" $ do
        route $ setExtension "html"
        compile $ pandocCompiler
            >>= loadAndApplyTemplate "templates/post.html"    postCtx
            >>= loadAndApplyTemplate "templates/default.html" postCtx
            >>= relativizeUrls

    create ["archive.html"] $ do
        route idRoute
        compile $ do
            posts <- recentFirst =<< loadAll "posts/*"
            let archiveCtx =
                    listField "posts" postCtx (return posts) `mappend`
                    constField "title" "Заметки"             `mappend`
                    defaultContext

            makeItem ""
                >>= loadAndApplyTemplate "templates/archive.html" archiveCtx
                >>= loadAndApplyTemplate "templates/default.html" archiveCtx
                >>= relativizeUrls


    match "index.html" $ do
        route idRoute
        compile $ do
            posts <- recentFirst =<< loadAll "posts/*"
            let indexCtx =
                    listField "posts" postCtx (return posts) `mappend`
                    defaultContext

            getResourceBody
                >>= applyAsTemplate indexCtx
                >>= loadAndApplyTemplate "templates/default.html" indexCtx
                >>= relativizeUrls

    match "templates/*" $ compile templateBodyCompiler

postCtx :: Context String
postCtx =
    dateField "date" "%B %e, %Y" `mappend`
    defaultContext

xelatex :: Item String -> Compiler (Item TmpFile)
xelatex item = do
    TmpFile mdPath <- newTmpFile "tmp.md"
    let pdfPath = replaceExtension mdPath "pdf"
    unsafeCompiler $ do
        writeFile mdPath $ itemBody item
        exitCode <- Process.system $ unwords ["pandoc", mdPath
            , "--latex-engine=xelatex" , "-V", "mainfont=\"Liberation Serif\""
            , "-o", pdfPath]
        case exitCode of
                System.Exit.ExitSuccess -> return ()
                _ -> error "Can't convert markdown to pdf."
    makeItem $ TmpFile pdfPath

