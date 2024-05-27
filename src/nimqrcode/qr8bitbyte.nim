import qrbitbuffer, qrconsts

export qrbitbuffer, qrconsts

type
  QR8bitByte* = ref object
    mode*: QRMode
    data*: string

proc newQR8bitByte*(data: string): QR8bitByte =
  result.new
  result.mode = QRMode.BYTE
  result.data = data

proc write*(self: QR8bitByte, buf: QRBitBuffer) =
  for ch in self.data:
    buf.put(ch.int, 8)
