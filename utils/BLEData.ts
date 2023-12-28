export interface BLEData {
  timestamp: number;
  value: number;
}

export function decodePacket(data: number[]): BLEData {
  let timestamp = 0, value = 0;

  let i = 0;
  while (i < 4) {
    timestamp += data[i] << (i * 8);
    i++;
  }
  while (i < 8) {
    value += data[i] << ((i - 4) * 8);
    i++;
  }

  return { timestamp, value };
}
