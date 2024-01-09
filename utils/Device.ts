import { createContext } from "react";

export interface BLEDevice {
  peripheral: string;
  characteristic: string;
  service: string;
}

export type DeviceContextType = {
  device: BLEDevice | null;
  setDevice: (device: BLEDevice | null) => void;
};

export const DeviceContext = createContext<DeviceContextType | null>(null);
