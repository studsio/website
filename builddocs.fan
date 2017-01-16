#! /usr/bin/env fan
//
// Copyright (c) 2017, Andy Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   15 Jan 2017  Andy Frank  Creation
//

using build
using fanr
using util

**
** Build core/docs/markdown to HTML
**
class BuildDocs
{
  const File scriptFile := File(typeof->sourceFile.toStr.toUri).normalize
  const File scriptDir  := scriptFile.parent
  const File srcDir     := (scriptDir + `../core/doc/`).normalize
  const File outDir     := (scriptDir + `doc/`).normalize

  Void bash(Str cmd) { Process(["bash", "-c", cmd]).run.join }

  Int main()
  {
    try
    {
      echo("BuildDocs [$srcDir.osPath]")
      bash("rm $outDir.osPath/*.html")
      writeIndex
      srcDir.listFiles.each |f|
      {
        echo(" $f.name")
        out := outDir + `${f.basename}.html`
        printHeader(out)
        bash("pandoc -S -f markdown $f.osPath >> $out.osPath")
        printFooter(out)
      }
      return 0
    }
    catch (Err err)
    {
      err.trace
      return 1
    }
  }

  Void writeIndex()
  {
    index := outDir + `index.html`
    printHeader(index)
    out := index.out(true)
    out.printLine("<h1>Documentation Index</h1>")
    out.printLine("<ul>")
    srcDir.listFiles.sort |a,b| { a.basename <=> b.basename }.each |f|
    {
      uri := "${f.basename}.html"
      out.printLine("<li><a href='$uri'>$f.basename.toXml</a></li>")
    }
    out.printLine("</ul>")
    out.flush.close
    printFooter(index)
  }

  Void printHeader(File f)
  {
    f.out.print(
     """<!DOCTYPE html>
        <html xmlns='http://www.w3.org/1999/xhtml'>
        <head>
          <title>$f.basename &ndash; Studs</title>
          <meta http-equiv='Content-Type' content='text/html; charset=utf-8' />
          <!--
          <meta name='viewport' content='initial-scale=1.0' />
          <meta name='description' content='' />
          -->
          <link href='https://fonts.googleapis.com/css?family=Roboto:700,400' rel='stylesheet' type='text/css'>
          <link href='https://fonts.googleapis.com/css?family=Roboto+Mono:700,400' rel='stylesheet' type='text/css'>
          <link rel='stylesheet' type='text/css' href='doc.css' />
        </head>
        <body>
        <header>
          <a href='../index.html'>Home</a>
          <a href='index.html'>Index</a>
          <a href='https://bitbucket.org/studs/core'>BitBucket</a>
        </header>
        """).flush.close
  }

  Void printFooter(File f)
  {
    f.out(true).print(
     """<footer>
        </footer>
        </body>
        </html>
        """).flush.close
  }
}
