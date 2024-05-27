import std/[
  strutils,
  terminal
]

import qrcode



const GAP = 1

proc showQRInTerminal*(msg: string) =
  let qr = newQRCode()
  qr.addData(msg)
  qr.make

  for _ in 0 ..< GAP:
    stdout.styledWriteLine(bgWhite, "  ".repeat(qr.moduleCnt + GAP * 2))
  for r in 0 ..< qr.moduleCnt:
    stdout.styledWrite(bgWhite, "  ".repeat(GAP))
    for c in 0 ..< qr.moduleCnt:
      if qr.isDark(r, c):
        stdout.styledWrite(bgBlack, "  ")
      else:
        stdout.styledWrite(bgWhite, "  ")
    stdout.styledWriteLine(bgWhite, "  ".repeat(GAP))
  for _ in 0 ..< GAP:
    stdout.styledWriteLine(bgWhite, "  ".repeat(qr.moduleCnt + GAP * 2))
