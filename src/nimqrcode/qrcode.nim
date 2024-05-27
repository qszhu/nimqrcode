# https://github.com/gtanner/qrcode-terminal
import std/[
  bitops,
  math,
  sequtils,
]

import qr8bitbyte, qrpolynomial



const EMPTY = -1
const LIGHT = 0
const DARK = 1

proc getColor(b: bool): int {.inline.} =
  if b: DARK else: LIGHT

type
  QRCode* = ref object
    typeNum: int
    correctLevel: QRErrorCorrectLevel
    dataList: seq[QR8bitByte]
    moduleCnt*: int
    modules: seq[seq[int]]
    dataCache: seq[uint8]

proc newQRCode*(typeNum = 0, correctLevel = QRErrorCorrectLevel.L): QRCode =
  result.new
  result.typeNum = typeNum
  result.correctLevel = correctLevel

proc addData*(self: QRCode, data: string) =
  self.dataList.add newQR8bitByte(data)

proc isDark*(self: QRCode, r, c: int): bool {.inline.} =
  doAssert r in 0 ..< self.moduleCnt and c in 0 ..< self.moduleCnt
  self.modules[r][c] == DARK

proc detectTypeNum(self: QRCode): int =
  if self.typeNum > 0: return self.typeNum
  for typeNum in 1 ..< 40:
    let rsBlocks = getRSBlocks(typeNum, self.correctLevel)
    var buffer = newQRBitBuffer()
    for data in self.dataList:
      buffer.put(data.mode.int, 4)
      buffer.put(data.data.len, data.mode.lenInBits(typeNum))
      data.write(buffer)
    let total = rsBlocks.mapIt(it.dataCount).sum
    if buffer.lenInBits <= total * 8: return typeNum

proc getLostPointLvl1(self: QRCode): int =
  let mc = self.moduleCnt
  for r in 0 ..< mc:
    for c in 0 ..< mc:
      var sameCnt = 0
      for dr in -1 .. 1:
        for dc in -1 .. 1:
          if (dr, dc) == (0, 0): continue
          let (nr, nc) = (r + dr, c + dc)
          if nr notin 0 ..< mc: continue
          if nc notin 0 ..< mc: continue
          if self.isDark(nr, nc) == self.isDark(r, c):
            sameCnt += 1
      if sameCnt > 5:
        result += (3 + sameCnt - 5)

proc getLostPointLvl2(self: QRCode): int =
  let mc = self.moduleCnt
  for r in 0 ..< mc - 1:
    for c in 0 ..< mc - 1:
      var cnt = 0
      if self.isDark(r, c): cnt += 1
      if self.isDark(r + 1, c): cnt += 1
      if self.isDark(r, c + 1): cnt += 1
      if self.isDark(r + 1, c + 1): cnt += 1
      if cnt == 0 or cnt == 4:
        result += 3

proc getLostPointLvl3(self: QRCode): int =
  let mc = self.moduleCnt

  for r in 0 ..< mc:
    for c in 0 ..< mc - 6:
      if self.isDark(r, c) and
        not self.isDark(r, c + 1) and
        self.isDark(r, c + 2) and
        self.isDark(r, c + 3) and
        self.isDark(r, c + 4) and
        not self.isDark(r, c + 5) and
        self.isDark(r, c + 6):
        result += 40

  for c in 0 ..< mc:
    for r in 0 ..< mc - 6:
      if self.isDark(r, c) and
        not self.isDark(r + 1, c) and
        self.isDark(r + 2, c) and
        self.isDark(r + 3, c) and
        self.isDark(r + 4, c) and
        not self.isDark(r + 5, c) and
        self.isDark(r + 6, c):
        result += 40

proc getLostPointLvl4(self: QRCode): float =
  let mc = self.moduleCnt
  var darkCnt = 0
  for r in 0 ..< mc:
    for c in 0 ..< mc:
      if self.isDark(r, c): darkCnt += 1
  let ratio = abs(darkCnt * 100 / (mc * mc) - 50) / 5
  ratio * 10

proc getLostPoint(self: QRCode): float =
  var l = self.getLostPointLvl1.float
  result += l
  l = self.getLostPointLvl2.float
  result += l
  l = self.getLostPointLvl3.float
  result += l
  l = self.getLostPointLvl4.float
  result += l

proc makeImpl(self: QRCode, test: bool, maskPat: QRMaskPattern)
proc getBestMaskPattern(self: QRCode): QRMaskPattern =
  var minLostPoint = 0.0
  for maskPat in QRMaskPattern:
    self.makeImpl(true, maskPat)
    let lostPoint = self.getLostPoint
    if maskPat == QRMaskPattern.PATTERN000 or minLostPoint > lostPoint:
      minLostPoint = lostPoint
      result = maskPat

proc setupPositionProbePattern(self: QRCode, r, c: int) =
  let mc = self.moduleCnt
  for dr in -1 .. 7:
    for dc in -1 .. 7:
      let (nr, nc) = (r + dr, c + dc)
      if nr notin 0 ..< mc: continue
      if nc notin 0 ..< mc: continue
      self.modules[nr][nc] = getColor(
        dr in 0 .. 6 and dc in [0, 6] or
        dr in [0, 6] and dc in 0 .. 6 or
        dr in 2 .. 4 and dc in 2 .. 4
      )

proc setupPositionAdjustPattern(self: QRCode) =
  let pos = getPatternPosition(self.typeNum)
  for r in pos:
    for c in pos:
      if self.modules[r][c] != EMPTY: continue
      for dr in -2 .. 2:
        for dc in -2 .. 2:
          let (nr, nc) = (r + dr, c + dc)
          self.modules[nr][nc] = getColor(
            dr.abs == 2 or
            dc.abs == 2 or
            (r, c) == (0, 0)
          )

proc setupTimingPattern(self: QRCode) =
  let mc = self.moduleCnt

  for r in 8 ..< mc - 8:
    if self.modules[r][6] != EMPTY: continue
    self.modules[r][6] = getColor(r mod 2 == 0)

  for c in 8 ..< mc - 8:
    if self.modules[6][c] != EMPTY: continue
    self.modules[6][c] = getColor(c mod 2 == 0)

proc setupTypeInfo(self: QRCode, test: bool, maskPat: QRMaskPattern) =
  let mc = self.moduleCnt
  let data = (self.correctLevel.int shl 3) or maskPat.ord
  let bits = getBCHTypeInfo(data)

  for r in 0 ..< 15:
    let m = getColor(not test and bits.testBit(r))
    if r < 6:
      self.modules[r][8] = m
    elif r < 8:
      self.modules[r + 1][8] = m
    else:
      self.modules[mc - (15 - r)][8] = m

  for c in 0 ..< 15:
    let m = getColor(not test and bits.testBit(c))
    if c < 8:
      self.modules[8][mc - (c + 1)] = m
    elif c < 9:
      self.modules[8][15 - (c + 1) + 1] = m
    else:
      self.modules[8][15 - (c + 1)] = m

  self.modules[mc - 8][8] = getColor(not test)

proc setupTypeNumber(self: QRCode, test: bool) =
  let mc = self.moduleCnt
  let bits = getBCHTypeInfo(self.typeNum)

  for i in 0 ..< 18:
    let m = getColor(not test and bits.testBit(i))
    let a = i div 3
    let b = i mod 3 + mc - 8 - 3
    self.modules[a][b] = m
    self.modules[b][a] = m

proc createBytes(buffer: QRBitBuffer, rsBlocks: seq[QRRSBlock]): seq[uint8] =
  var offset, maxDcCnt, maxEcCnt = 0
  var dcData, ecData = newSeq[seq[uint8]](rsBlocks.len)
  for i in 0 ..< rsBlocks.len:
    var dcCnt = rsBlocks[i].dataCount
    var ecCnt = rsBlocks[i].totalCount - dcCnt
    maxDcCnt = maxDcCnt.max dcCnt
    maxEcCnt = maxEcCnt.max ecCnt

    dcData[i] = newSeq[uint8](dcCnt)
    for j in 0 ..< dcData[i].len:
      dcData[i][j] = (buffer.buf[offset + j] and 0xff).uint8
    offset += dcCnt

    var rsPoly = getErrorCorrectPolynomial(ecCnt)
    var rawPoly = newQRPolynomial(dcData[i], rsPoly.len - 1)
    var modPoly = rawPoly mod rsPoly
    ecData[i] = newSeq[uint8](rsPoly.len - 1)
    for j in 0 ..< ecData[i].len:
      let modIdx = j + modPoly.len - ecData[i].len
      ecData[i][j] = if modIdx >= 0: modPoly[modIdx] else: 0'u8

  let totalCodeCnt = rsBlocks.mapIt(it.totalCount).sum
  result = newSeq[uint8](totalCodeCnt)
  var i = 0
  for c in 0 ..< maxDcCnt:
    for r in 0 ..< rsBlocks.len:
      if c < dcData[r].len:
        result[i] = dcData[r][c]
        i += 1
  for c in 0 ..< maxEcCnt:
    for r in 0 ..< rsBlocks.len:
      if c < ecData[r].len:
        result[i] = ecData[r][c]
        i += 1

const PAD0 = 0xEC
const PAD1 = 0x11

proc createData(self: QRCode): seq[uint8] =
  if self.dataCache.len > 0: return self.dataCache

  # TODO: DRY
  let rsBlocks = getRSBlocks(self.typeNum, self.correctLevel)
  var buffer = newQRBitBuffer()
  for data in self.dataList:
    buffer.put(data.mode.int, 4)
    buffer.put(data.data.len, data.mode.lenInBits(self.typeNum))
    data.write(buffer)
  let total = rsBlocks.mapIt(it.dataCount).sum
  if buffer.lenInBits > total * 8:
    raise newException(CatchableError, "Code length overflow.")

  if buffer.lenInBits + 4 <= total * 8:
    buffer.put(0, 4)

  while buffer.lenInBits mod 8 != 0:
    buffer.putBit(0)

  while true:
    if buffer.lenInBits >= total * 8: break
    buffer.put(PAD0, 8)
    if buffer.lenInBits >= total * 8: break
    buffer.put(PAD1, 8)

  createBytes(buffer, rsBlocks)

proc mapData(self: QRCode, maskPat: QRMaskPattern) =
  let data = self.dataCache
  let mc = self.moduleCnt
  var inc = -1
  var r = mc - 1
  var bitIdx = 7
  var byteIdx = 0
  var c = mc - 1
  while c > 0:
    if c == 6: c -= 1
    while true:
      for dc in 0 ..< 2:
        if self.modules[r][c - dc] != EMPTY: continue
        var dark = false
        if byteIdx < data.len:
          dark = data[byteIdx].testBit(bitIdx)
        let mask = getMask(maskPat, r, c - dc)
        if mask: dark = not dark
        self.modules[r][c - dc] = getColor(dark)
        bitIdx -= 1
        if bitIdx < 0:
          bitIdx = 7
          byteIdx += 1
      r += inc
      if r notin 0 ..< mc:
        r -= inc
        inc = -inc
        break
    c -= 2

proc makeImpl(self: QRCode, test: bool, maskPat: QRMaskPattern) =
  self.moduleCnt = self.typeNum * 4 + 17
  self.modules = newSeqWith(self.moduleCnt, newSeq[int](self.moduleCnt))
  for r in 0 ..< self.moduleCnt:
    for c in 0 ..< self.moduleCnt:
      self.modules[r][c] = EMPTY

  self.setupPositionProbePattern(0, 0)
  self.setupPositionProbePattern(self.moduleCnt - 7, 0)
  self.setupPositionProbePattern(0, self.moduleCnt - 7)
  self.setupPositionAdjustPattern
  self.setupTimingPattern
  self.setupTypeInfo(test, maskPat)

  if self.typeNum >= 7:
    self.setupTypeNumber(test)

  self.dataCache = self.createData
  self.mapData(maskPat)

proc make*(self: QRCode) =
  self.typeNum = self.detectTypeNum
  self.makeImpl(false, self.getBestMaskPattern)
