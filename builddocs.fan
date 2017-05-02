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
  const File docSrcDir  := (scriptDir + `../core/doc/`).normalize
  const File docOutDir  := (scriptDir + `doc/`).normalize
  const File tutSrcDir  := (scriptDir + `../core/docTut/`).normalize
  const File tutOutDir  := (scriptDir + `tut/`).normalize
  const File apiDir     := (scriptDir + `api/`).normalize

  Void bash(Str cmd) { Process(["bash", "-c", cmd]).run.join }

  ** Table of contents.
  Str:Str[] toc := [:]
  {
    it.ordered = true
    it.set("Overview", ["AboutStuds", "GettingStarted", "Changelog"])
    it.set("Basics",   ["Building", "Daemons", "faninit", "Pack"])
    it.set("Network",  ["Networking", "NTP"])
    it.set("I/O",      ["Led", "Gpio", "I2C", "Spi", "Uart"])
    it.set("System",   ["Systems"])
  }

  ** Tutorials
  Str[] tuts :=
  [
    "Tutorials",
    "Console",
    "UartGps",
  ]

  Int main()
  {
    try
    {
      buildDocs
      buildTuts
      buildApis
      return 0
    }
    catch (Err err)
    {
      err.trace
      return 1
    }
  }

//////////////////////////////////////////////////////////////////////////
// Docs
//////////////////////////////////////////////////////////////////////////

  Void buildDocs()
  {
    echo("BuildDocs [$docSrcDir.osPath]")

    // cleanup old docs
    bash("rm $docOutDir.osPath/*.html")
    bash("rm $docOutDir.osPath/*.svg")

    // copy artwork
    docSrcDir.listFiles.each |f|
    {
      if (f.ext == "svg") f.copyTo(docOutDir + `$f.name`, ["overwrite":true])
    }

    done := File[,]

    // render chapters
    toc.each |chapters|
    {
      chapters.each |ch|
      {
        f := docSrcDir + `${ch}.md`
        done.add(f)

        echo(" $f.name")
        out := docOutDir + `${f.basename}.html`
        printHeader(out)
        bash("pandoc -S -f markdown $f.osPath >> $out.osPath")
        printToc(out)
        printFooter(out)
      }
    }

    // sanity check
    md := docSrcDir.listFiles.findAll |f| { f.ext=="md" }
    if (md.size != done.size)
    {
      echo("**\n** FAILED: source != toc\n**")
      Env.cur.exit(1)
    }
  }

  Void printToc(File f)
  {
    chapter := f.basename

    map := Str:Str[:] { ordered=true }
    f.in.readAllLines.each |s|
    {
      if (s.startsWith("<h1 id=") || s.startsWith("<h2 id=") || s.startsWith("<h3 id="))
      {
        start := "<h1 id=\"".size
        end   := s.index("\"", start+1)
        name  := s[start..<end]
        map[name] = s[1..2]
      }
    }

    out := f.out(true)
    out.printLine("<aside>")

    toc.each |chapters, section|
    {
      out.printLine("</ul><h3>$section</h3>")
      out.printLine("<ul>")
      chapters.each |ch|
      {
        if (ch == f.basename)
        {
          map.each |v,k|
          {
            dis := toDis(k)
            out.printLine("<li class='$v'><a href='#$k'>$dis</a></li>")
          }
        }
        else
        {
          dis := ch=="I2C" ? ch : ch.toDisplayName
          out.printLine("<li class='h1'><a href='${ch}.html'>$dis</a></li>")
        }
      }
      out.printLine("</ul>")
    }

    out.printLine("</aside>")
    out.flush.close
  }

//////////////////////////////////////////////////////////////////////////
// Tutorials
//////////////////////////////////////////////////////////////////////////

  Void buildTuts()
  {
    echo("BuildTuts [$tutSrcDir.osPath]")

    // cleanup old docs
    bash("rm $tutOutDir.osPath/*.html")
    bash("rm $tutOutDir.osPath/*.png")

    // copy artwork
    tutSrcDir.listFiles.each |f|
    {
      if (f.ext == "png") f.copyTo(tutOutDir + `$f.name`, ["overwrite":true])
    }

    done := File[,]

    // render chapters
    tuts.each |tut|
    {
      f := tutSrcDir + `${tut}.md`
      done.add(f)

      echo(" $f.name")
      out := tutOutDir + `${f.basename}.html`
      printHeader(out, readTutTitle(f))
      bash("pandoc -S -f markdown $f.osPath >> $out.osPath")
      printTuts(out)
      printFooter(out)
    }

    // sanity check
    md := tutSrcDir.listFiles.findAll |f| { f.ext=="md" }
    if (md.size != done.size)
    {
      echo("**\n** FAILED: source != tut\n**")
      Env.cur.exit(1)
    }
  }

  Void printTuts(File f)
  {
    out := f.out(true)
    out.printLine("<aside>")

    out.printLine("<ul class='tut'>")
    out.printLine("<li><a href='Tutorials.html'>Tutorials</a></li>")
    tuts.eachRange(1..-1) |tut|
    {
      h := readTutTitle(tutSrcDir + `${tut}.md`)
      out.printLine("<li><a href='${tut}.html'>$h.toXml</a></li>")
    }
    out.printLine("</ul>")

    out.printLine("</aside>")
    out.flush.close
  }

  Str readTutTitle(File f)
  {
    in := f.in
    title := in.readLine[1..-1]
    in.close
    return title
  }

//////////////////////////////////////////////////////////////////////////
// APIs
//////////////////////////////////////////////////////////////////////////

  Void buildApis()
  {
    echo("BuildApis [$apiDir.osPath]")

    // cleanup old docs
    bash("rm $apiDir.osPath/studs/*.html")

    // run compilerDoc
    bash("cd $scriptDir.osPath/../core; fan compilerDoc studs -outDir $apiDir.osPath")

    // rewrite api files
    (apiDir + `studs/`).listFiles.each |f|
    {
      echo("  $f.name")

      // strip compilerDoc headers
      markup := f.readAllStr
      s := markup.index("<div class='mainSidebar'>")
      e := markup.index("</body>")
      markup = markup[s..<e]

      // fixup markup
      if (f.name == "index.html")
      {
        markup = markup.replace("<div class='mainSidebar'>", "<div class='mainSidebar index'>")
      }
      else
      {
        markup = "<p class='api-index'><a href='index.html'>All Types</a></p>" + markup
      }

      // rewrite ext doc links
      // TODO: check non-sys...
      markup = markup.replace("<a href='../sys", "<a href='http://fantom.org/doc/sys")

      // rewrite html
      printHeader(f)
      f.out(true).printLine(markup).flush.close
      printFooter(f)
    }
  }

//////////////////////////////////////////////////////////////////////////
// Theme
//////////////////////////////////////////////////////////////////////////

  Void printHeader(File f, Str? title := null)
  {
    path := f.pathStr.contains("api/studs/") ? "../.." : ".."
    f.out.print(
     """<!DOCTYPE html>
        <html xmlns='http://www.w3.org/1999/xhtml'>
        <head>
          <title>${title ?: f.basename} &ndash; Studs</title>
          <meta http-equiv='Content-Type' content='text/html; charset=utf-8' />
          <!--
          <meta name='viewport' content='initial-scale=1.0' />
          <meta name='description' content='' />
          -->
          <link href='https://fonts.googleapis.com/css?family=Roboto:700,400' rel='stylesheet' type='text/css'>
          <link href='https://fonts.googleapis.com/css?family=Roboto+Mono:700,400' rel='stylesheet' type='text/css'>
          <link rel='stylesheet' type='text/css' href='${path}/doc.css' />
        </head>
        <body>
        <header>
          <a href='${path}/index.html'>Home</a>
          <a href='${path}/doc/AboutStuds.html'>Documentation</a>
          <a href='${path}/tut/Tutorials.html'>Tutorials</a>
          <a href='${path}/api/studs/index.html'>API</a>
          <a href='https://bitbucket.org/studs'>BitBucket</a>
        </header>
        <div class='main'>
        """).flush.close
  }

  Void printFooter(File f)
  {
    f.out(true).print(
     """</div>
        <footer>
        </footer>
        </body>
        </html>
        """).flush.close
  }

  Str toDis(Str name, Int sep := '-')
  {
    name.lower.split(sep).map |s|
    {
      if (s == "a")     return "a"
      if (s == "your")  return "your"
      if (s == "jre")   return "JRE"
      if (s == "i2c")   return "I2C"
      if (s == "io")    return "I/O"
      if (s == "ip")    return "IP"
      if (s == "macos") return "MacOS"
      if (s == "onoff") return "On/Off"
      return s.capitalize
    }.join(" ")
  }
}