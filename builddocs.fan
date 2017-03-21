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

  ** Table of contents.
  Str:Str[] toc := [:]
  {
    it.ordered = true
    it.set("Overview", ["AboutStuds", "GettingStarted"])
    it.set("Basics",   ["Building", "Daemons", "faninit", "Pack"])
    it.set("Network",  ["Networking", "NTP"])
    it.set("I/O",      ["Leds", "Uart"])
    it.set("System",   ["Systems"])
  }

  Int main()
  {
    try
    {
      echo("BuildDocs [$srcDir.osPath]")

      // cleanup old docs
      bash("rm $outDir.osPath/*.html")

      // copy artwork
      srcDir.listFiles.each |f|
      {
        if (f.ext == "svg") f.copyTo(outDir + `$f.name`, ["overwrite":true])
      }

      done := File[,]

      // render chapters
      toc.each |chapters|
      {
        chapters.each |ch|
        {
          f := srcDir + `${ch}.md`
          done.add(f)

          echo(" $f.name")
          out := outDir + `${f.basename}.html`
          printHeader(out)
          bash("pandoc -S -f markdown $f.osPath >> $out.osPath")
          printToc(out)
          printFooter(out)
        }
      }

      // sanity check
      md := srcDir.listFiles.findAll |f| { f.ext=="md" }
      if (md.size != done.size)
      {
        echo("**\n** FAILED: source != toc\n**")
        return 1
      }
      else
      {
        echo("SUCCESS!")
        return 0
      }
    }
    catch (Err err)
    {
      err.trace
      return 1
    }
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
          <a href='AboutStuds.html'>Documentation</a>
          <a href='https://bitbucket.org/studs/core'>BitBucket</a>
        </header>
        <div class='main'>
        """).flush.close
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
          dis := ch.toDisplayName
          out.printLine("<li class='h1'><a href='${ch}.html'>$dis</a></li>")
        }
      }
      out.printLine("</ul>")
    }

    out.printLine("</aside>")
    out.flush.close
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
      if (s == "io")    return "I/O"
      if (s == "ip")    return "IP"
      if (s == "macos") return "MacOS"
      return s.capitalize
    }.join(" ")
  }
}