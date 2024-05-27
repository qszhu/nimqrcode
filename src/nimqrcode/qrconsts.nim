import std/[
  bitops,
]



type
  QRErrorCorrectLevel* = enum
    M = 0
    L = 1
    H = 2
    Q = 3



type
  QRMode* = enum
    NUMBER = 1 shl 0
    ALPHA_NUM = 1 shl 1
    BYTE = 1 shl 2
    KANJI = 1 shl 3

proc lenInBits*(mode: QRMode, typeNum: int): int =
  case typeNum
  of 1 .. 9:
    case mode
    of QRMode.NUMBER: 10
    of QRMode.ALPHA_NUM: 9
    of QRMode.BYTE: 8
    of QRMode.KANJI: 8
  of 10 .. 26:
    case mode
    of QRMode.NUMBER: 12
    of QRMode.ALPHA_NUM: 11
    of QRMode.BYTE: 16
    of QRMode.KANJI: 10
  of 27 .. 40:
    case mode
    of QRMode.NUMBER: 14
    of QRMode.ALPHA_NUM: 13
    of QRMode.BYTE: 16
    of QRMode.KANJI: 12
  else:
    raise newException(ValueError, "Unknown type: " & $typeNum)



const RS_BLOCK_TABLE = @[
  # 1
  @[1, 26, 19],
  @[1, 26, 16],
  @[1, 26, 13],
  @[1, 26, 9],

  # 2
  @[1, 44, 34],
  @[1, 44, 28],
  @[1, 44, 22],
  @[1, 44, 16],

  # 3
  @[1, 70, 55],
  @[1, 70, 44],
  @[2, 35, 17],
  @[2, 35, 13],

  # 4
  @[1, 100, 80],
  @[2, 50, 32],
  @[2, 50, 24],
  @[4, 25, 9],

  # 5
  @[1, 134, 108],
  @[2, 67, 43],
  @[2, 33, 15, 2, 34, 16],
  @[2, 33, 11, 2, 34, 12],

  # 6
  @[2, 86, 68],
  @[4, 43, 27],
  @[4, 43, 19],
  @[4, 43, 15],

  # 7
  @[2, 98, 78],
  @[4, 49, 31],
  @[2, 32, 14, 4, 33, 15],
  @[4, 39, 13, 1, 40, 14],

  # 8
  @[2, 121, 97],
  @[2, 60, 38, 2, 61, 39],
  @[4, 40, 18, 2, 41, 19],
  @[4, 40, 14, 2, 41, 15],

  # 9
  @[2, 146, 116],
  @[3, 58, 36, 2, 59, 37],
  @[4, 36, 16, 4, 37, 17],
  @[4, 36, 12, 4, 37, 13],

  # 10
  @[2, 86, 68, 2, 87, 69],
  @[4, 69, 43, 1, 70, 44],
  @[6, 43, 19, 2, 44, 20],
  @[6, 43, 15, 2, 44, 16],

  # 11
  @[4, 101, 81],
  @[1, 80, 50, 4, 81, 51],
  @[4, 50, 22, 4, 51, 23],
  @[3, 36, 12, 8, 37, 13],

  # 12
  @[2, 116, 92, 2, 117, 93],
  @[6, 58, 36, 2, 59, 37],
  @[4, 46, 20, 6, 47, 21],
  @[7, 42, 14, 4, 43, 15],

  # 13
  @[4, 133, 107],
  @[8, 59, 37, 1, 60, 38],
  @[8, 44, 20, 4, 45, 21],
  @[12, 33, 11, 4, 34, 12],

  # 14
  @[3, 145, 115, 1, 146, 116],
  @[4, 64, 40, 5, 65, 41],
  @[11, 36, 16, 5, 37, 17],
  @[11, 36, 12, 5, 37, 13],

  # 15
  @[5, 109, 87, 1, 110, 88],
  @[5, 65, 41, 5, 66, 42],
  @[5, 54, 24, 7, 55, 25],
  @[11, 36, 12],

  # 16
  @[5, 122, 98, 1, 123, 99],
  @[7, 73, 45, 3, 74, 46],
  @[15, 43, 19, 2, 44, 20],
  @[3, 45, 15, 13, 46, 16],

  # 17
  @[1, 135, 107, 5, 136, 108],
  @[10, 74, 46, 1, 75, 47],
  @[1, 50, 22, 15, 51, 23],
  @[2, 42, 14, 17, 43, 15],

  # 18
  @[5, 150, 120, 1, 151, 121],
  @[9, 69, 43, 4, 70, 44],
  @[17, 50, 22, 1, 51, 23],
  @[2, 42, 14, 19, 43, 15],

  # 19
  @[3, 141, 113, 4, 142, 114],
  @[3, 70, 44, 11, 71, 45],
  @[17, 47, 21, 4, 48, 22],
  @[9, 39, 13, 16, 40, 14],

  # 20
  @[3, 135, 107, 5, 136, 108],
  @[3, 67, 41, 13, 68, 42],
  @[15, 54, 24, 5, 55, 25],
  @[15, 43, 15, 10, 44, 16],

  # 21
  @[4, 144, 116, 4, 145, 117],
  @[17, 68, 42],
  @[17, 50, 22, 6, 51, 23],
  @[19, 46, 16, 6, 47, 17],

  # 22
  @[2, 139, 111, 7, 140, 112],
  @[17, 74, 46],
  @[7, 54, 24, 16, 55, 25],
  @[34, 37, 13],

  # 23
  @[4, 151, 121, 5, 152, 122],
  @[4, 75, 47, 14, 76, 48],
  @[11, 54, 24, 14, 55, 25],
  @[16, 45, 15, 14, 46, 16],

  # 24
  @[6, 147, 117, 4, 148, 118],
  @[6, 73, 45, 14, 74, 46],
  @[11, 54, 24, 16, 55, 25],
  @[30, 46, 16, 2, 47, 17],

  # 25
  @[8, 132, 106, 4, 133, 107],
  @[8, 75, 47, 13, 76, 48],
  @[7, 54, 24, 22, 55, 25],
  @[22, 45, 15, 13, 46, 16],

  # 26
  @[10, 142, 114, 2, 143, 115],
  @[19, 74, 46, 4, 75, 47],
  @[28, 50, 22, 6, 51, 23],
  @[33, 46, 16, 4, 47, 17],

  # 27
  @[8, 152, 122, 4, 153, 123],
  @[22, 73, 45, 3, 74, 46],
  @[8, 53, 23, 26, 54, 24],
  @[12, 45, 15, 28, 46, 16],

  # 28
  @[3, 147, 117, 10, 148, 118],
  @[3, 73, 45, 23, 74, 46],
  @[4, 54, 24, 31, 55, 25],
  @[11, 45, 15, 31, 46, 16],

  # 29
  @[7, 146, 116, 7, 147, 117],
  @[21, 73, 45, 7, 74, 46],
  @[1, 53, 23, 37, 54, 24],
  @[19, 45, 15, 26, 46, 16],

  # 30
  @[5, 145, 115, 10, 146, 116],
  @[19, 75, 47, 10, 76, 48],
  @[15, 54, 24, 25, 55, 25],
  @[23, 45, 15, 25, 46, 16],

  # 31
  @[13, 145, 115, 3, 146, 116],
  @[2, 74, 46, 29, 75, 47],
  @[42, 54, 24, 1, 55, 25],
  @[23, 45, 15, 28, 46, 16],

  # 32
  @[17, 145, 115],
  @[10, 74, 46, 23, 75, 47],
  @[10, 54, 24, 35, 55, 25],
  @[19, 45, 15, 35, 46, 16],

  # 33
  @[17, 145, 115, 1, 146, 116],
  @[14, 74, 46, 21, 75, 47],
  @[29, 54, 24, 19, 55, 25],
  @[11, 45, 15, 46, 46, 16],

  # 34
  @[13, 145, 115, 6, 146, 116],
  @[14, 74, 46, 23, 75, 47],
  @[44, 54, 24, 7, 55, 25],
  @[59, 46, 16, 1, 47, 17],

  # 35
  @[12, 151, 121, 7, 152, 122],
  @[12, 75, 47, 26, 76, 48],
  @[39, 54, 24, 14, 55, 25],
  @[22, 45, 15, 41, 46, 16],

  # 36
  @[6, 151, 121, 14, 152, 122],
  @[6, 75, 47, 34, 76, 48],
  @[46, 54, 24, 10, 55, 25],
  @[2, 45, 15, 64, 46, 16],

  # 37
  @[17, 152, 122, 4, 153, 123],
  @[29, 74, 46, 14, 75, 47],
  @[49, 54, 24, 10, 55, 25],
  @[24, 45, 15, 46, 46, 16],

  # 38
  @[4, 152, 122, 18, 153, 123],
  @[13, 74, 46, 32, 75, 47],
  @[48, 54, 24, 14, 55, 25],
  @[42, 45, 15, 32, 46, 16],

  # 39
  @[20, 147, 117, 4, 148, 118],
  @[40, 75, 47, 7, 76, 48],
  @[43, 54, 24, 22, 55, 25],
  @[10, 45, 15, 67, 46, 16],

  # 40
  @[19, 148, 118, 6, 149, 119],
  @[18, 75, 47, 31, 76, 48],
  @[34, 54, 24, 34, 55, 25],
  @[20, 45, 15, 61, 46, 16]
]

type
  QRRSBlock* = object
    totalCount*: int
    dataCount*: int

proc getRsBlockTable(typeNum: int, correctLevel: QRErrorCorrectLevel): seq[int] =
  case correctLevel
  of QRErrorCorrectLevel.L:
    return RS_BLOCK_TABLE[(typeNum - 1) * 4 + 0]
  of QRErrorCorrectLevel.M:
    return RS_BLOCK_TABLE[(typeNum - 1) * 4 + 1]
  of QRErrorCorrectLevel.Q:
    return RS_BLOCK_TABLE[(typeNum - 1) * 4 + 2]
  of QRErrorCorrectLevel.H:
    return RS_BLOCK_TABLE[(typeNum - 1) * 4 + 3]

proc getRsBlocks*(typeNum: int, correctLevel: QRErrorCorrectLevel): seq[QRRSBlock] =
  let rsBlock = getRsBlockTable(typeNum, correctLevel)
  for i in countup(0, rsBlock.len - 1, 3):
    let count = rsBlock[i + 0]
    let totalCount = rsBlock[i + 1]
    let dataCount = rsBlock[i + 2]
    for j in 0 ..< count:
      result.add QRRSBlock(totalCount: totalCount, dataCount: dataCount)



const PATTERN_POSITION_TABLE = @[
  @[],
  @[6, 18],
  @[6, 22],
  @[6, 26],
  @[6, 30],
  @[6, 34],
  @[6, 22, 38],
  @[6, 24, 42],
  @[6, 26, 46],
  @[6, 28, 50],
  @[6, 30, 54],
  @[6, 32, 58],
  @[6, 34, 62],
  @[6, 26, 46, 66],
  @[6, 26, 48, 70],
  @[6, 26, 50, 74],
  @[6, 30, 54, 78],
  @[6, 30, 56, 82],
  @[6, 30, 58, 86],
  @[6, 34, 62, 90],
  @[6, 28, 50, 72, 94],
  @[6, 26, 50, 74, 98],
  @[6, 30, 54, 78, 102],
  @[6, 28, 54, 80, 106],
  @[6, 32, 58, 84, 110],
  @[6, 30, 58, 86, 114],
  @[6, 34, 62, 90, 118],
  @[6, 26, 50, 74, 98, 122],
  @[6, 30, 54, 78, 102, 126],
  @[6, 26, 52, 78, 104, 130],
  @[6, 30, 56, 82, 108, 134],
  @[6, 34, 60, 86, 112, 138],
  @[6, 30, 58, 86, 114, 142],
  @[6, 34, 62, 90, 118, 146],
  @[6, 30, 54, 78, 102, 126, 150],
  @[6, 24, 50, 76, 102, 128, 154],
  @[6, 28, 54, 80, 106, 132, 158],
  @[6, 32, 58, 84, 110, 136, 162],
  @[6, 26, 54, 82, 110, 138, 166],
  @[6, 30, 58, 86, 114, 142, 170]
]

proc getPatternPosition*(typeNum: int): seq[int] =
  PATTERN_POSITION_TABLE[typeNum - 1]



#                  1111110000000000
#                  5432109876543210
const G15      = 0b0000010100110111
const G15_MASK = 0b0101010000010010

proc getBCHDigit(data: int): int {.inline.} =
  32 - data.uint32.countLeadingZeroBits

proc getBCHTypeInfo*(data: int): int =
  var d = data shl 10
  while getBCHDigit(d) - getBCHDigit(G15) >= 0:
    d = d xor (G15 shl (getBCHDigit(d) - getBCHDigit(G15)))
  ((data shl 10) or d) xor G15_MASK

type
  QRMaskPattern* = enum
    PATTERN000 = 0
    PATTERN001 = 1
    PATTERN010 = 2
    PATTERN011 = 3
    PATTERN100 = 4
    PATTERN101 = 5
    PATTERN110 = 6
    PATTERN111 = 7

proc getMask*(maskPat: QRMaskPattern, r, c: int): bool =
  case maskPat
  of QRMaskPattern.PATTERN000: (r + c) mod 2 == 0
  of QRMaskPattern.PATTERN001: r mod 2 == 0
  of QRMaskPattern.PATTERN010: c mod 3 == 0
  of QRMaskPattern.PATTERN011: (r + c) mod 3 == 0
  of QRMaskPattern.PATTERN100: (r div 2 + c div 3) mod 2 == 0
  of QRMaskPattern.PATTERN101: r * c mod 2 + r * c mod 3 == 0
  of QRMaskPattern.PATTERN110: (r * c mod 2 + r * c mod 3) mod 2 == 0
  of QRMaskPattern.PATTERN111: (r * c mod 3 + (r + c) mod 2) mod 2 == 0

proc initExpTable(): array[256, uint8] =
  for i in 0 ..< 8:
    result[i] = 1'u8 shl i
  for i in 8 ..< 256:
    result[i] = (
      result[i - 4] xor
      result[i - 5] xor
      result[i - 6] xor
      result[i - 8]
    )

const EXP_TABLE = initExpTable()

proc initLogTable(): array[256, int] =
  for i in 0 ..< 255:
    result[EXP_TABLE[i]] = i

const LOG_TABLE = initLogTable()

proc gExp*(n: int): uint8 {.inline.} =
  var n = n
  while n < 0: n += 255
  while n > 255: n -= 255
  EXP_TABLE[n]

proc gLog*(n: uint8): int {.inline.} =
  LOG_TABLE[n]
