import qrconsts



type
  QRPolynomial* = ref object
    nums: seq[uint8]

proc `$`*(self: QRPolynomial): string {.inline.} =
  $self.nums

proc newQRPolynomial*(nums: seq[uint8], shift: int): QRPolynomial =
  var o = 0
  while o < nums.len and nums[o] == 0: o += 1
  result.new
  result.nums = newSeq[uint8](nums.len - o + shift)
  for i in 0 ..< nums.len - o:
    result.nums[i] = nums[i + o]

proc len*(self: QRPolynomial): int {.inline.} =
  self.nums.len

proc `[]`*(self: QRPolynomial, i: int): uint8 {.inline.} =
  self.nums[i]

proc `*`*(a, b: QRPolynomial): QRPolynomial =
  var nums = newSeq[uint8](a.len + b.len - 1)
  for i in 0 ..< a.len:
    for j in 0 ..< b.len:
      nums[i + j] = nums[i + j] xor gExp(gLog(a[i]) + gLog(b[j]))
  newQRPolynomial(nums, 0)

template `*=`*(a, b: QRPolynomial) = a = a * b

proc `mod`*(a, b: QRPolynomial): QRPolynomial =
  if a.len - b.len < 0: return a
  let ratio = gLog(a[0]) - gLog(b[0])
  var nums = a.nums
  for i in 0 ..< b.len:
    nums[i] = nums[i] xor gExp(gLog(b[i]) + ratio)
  newQRPolynomial(nums, 0) mod b

proc getErrorCorrectPolynomial*(ecLen: int): QRPolynomial =
  result = newQRPolynomial(@[1'u8], 0)
  for i in 0 ..< ecLen:
    result *= newQRPolynomial(@[1'u8, gExp(i)], 0)
