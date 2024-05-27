import std/[
  bitops,
]



type
  QRBitBuffer* = ref object
    buf*: seq[int]
    bits: int

proc newQRBitBuffer*(): QRBitBuffer =
  result.new

proc putBit*(self: QRBitBuffer, bit: int) =
  let bufIdx = self.bits div 8
  if self.buf.len <= bufIdx:
    self.buf.add 0
  if bit == 1:
    self.buf[bufIdx].setBit(7 - self.bits mod 8)
  self.bits += 1

proc put*(self: QRBitBuffer, num, length: int) =
  # revered bits
  for i in 0 ..< length:
    let b = (num shr (length - 1 - i)) and 1
    self.putBit(b)

proc lenInBits*(self: QRBitBuffer): int =
  self.bits