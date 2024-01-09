export interface BLEData {
  timestamp: number;
  value: number;
}

export function decodePacket(data: number[]): BLEData[] {
  const result = [];

  const dataView = new DataView(new Uint8Array(data).buffer);

  let i = 0;
  while (i < data.length / 8) {
    const timestamp = dataView.getUint32(i * 8 + 0);
    const value = dataView.getFloat32(i * 8 + 4);

    result.push({ timestamp, value });
    i++;
  }

  return result;
}
