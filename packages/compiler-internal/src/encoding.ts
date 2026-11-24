export function encodeInt32(i: number): Uint8Array {
  const buffer = new ArrayBuffer(5);
  const dataView = new DataView(buffer);
  let n: number;
  if (i < 0) {
    if (i >= -256) {
      dataView.setUint8(0, 235);
      dataView.setUint8(1, i + 256);
      n = 2;
    } else if (i >= -65536) {
      dataView.setUint8(0, 236);
      dataView.setUint16(1, i + 65536, true);
      n = 3;
    } else {
      dataView.setUint8(0, 237);
      dataView.setInt32(1, i, true);
      n = 5;
    }
  } else if (i < 232) {
    dataView.setUint8(0, i);
    n = 1;
  } else if (i < 65536) {
    dataView.setUint8(0, 232);
    dataView.setUint16(1, i, true);
    n = 3;
  } else {
    dataView.setUint8(0, 233);
    dataView.setInt32(1, i, true);
    n = 5;
  }
  return new Uint8Array(buffer, 0, n);
}
