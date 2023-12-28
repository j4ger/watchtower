import ReanimatedGraph, { ReanimatedGraphPublicMethods } from "@birdwingo/react-native-reanimated-graph";
import { NativeStackNavigationProp } from "@react-navigation/native-stack";
import React, { useContext, useEffect, useRef, useState } from "react";
import { Appearance, EmitterSubscription, NativeEventEmitter, NativeModules, StyleSheet } from "react-native";
import { BleDisconnectPeripheralEvent, BleManagerDidUpdateValueForCharacteristicEvent } from "react-native-ble-manager";
import { GestureHandlerRootView } from "react-native-gesture-handler";
import { Toast } from "react-native-toast-message/lib/src/Toast";
import { RootStackParamList } from "../App";
import { BLEData, decodePacket } from "../utils/BLEData";
import { DeviceContext, DeviceContextType } from "../utils/device";

const BUFFER_SIZE = 100;

const BleManagerModule = NativeModules.BleManager;
const bleManagerEmitter = new NativeEventEmitter(BleManagerModule);

type Props = { navigation: NativeStackNavigationProp<RootStackParamList, "ECGSignal"> };

function ECGSignalView({ navigation }: Props): React.JSX.Element {
  const randomData = () => {
    const keys = new Array<number>();
    const values = new Array<number>();
    let i = 0;
    while (i < BUFFER_SIZE) {
      keys.push(i);
      values.push(Math.random() * 100);
      i++;
    }
    return [keys, values];
  };

  const graphRef = useRef<ReanimatedGraphPublicMethods>(null);

  let xData: number[] = [0, 1];
  let yData: number[] = [0, 0];
  const pushData = (newData: BLEData) => {
    let x, y;
    if (xData.length < BUFFER_SIZE) {
      x = [...xData, newData.timestamp];
      y = [...yData, newData.value];
    } else {
      x = [...xData.slice(1), newData.timestamp];
      y = [...yData.slice(1), newData.value];
    }
    xData = x;
    yData = y;
    graphRef.current?.updateData({ xAxis: x, yAxis: y });
  };

  let { device, setDevice } = useContext(DeviceContext) as DeviceContextType;

  let messageHandler: EmitterSubscription | null = null;
  let disconnectHandler: EmitterSubscription | null = null;
  useEffect(() => {
    // TODO: go back to first page when disconnect
    if (device) {
      messageHandler = bleManagerEmitter.addListener(
        "BleManagerDidUpdateValueForCharacteristic",
        (event: BleManagerDidUpdateValueForCharacteristicEvent) => {
          if (
            event.peripheral == device?.peripheral && event.service == device?.service
            && event.characteristic == device.characteristic
          ) {
            const bleData = decodePacket(event.value);
            // console.debug(`Decoded data: {timestamp: ${bleData.timestamp}, value: ${bleData.value}}`);
            pushData(bleData);
          }
        },
      );
      disconnectHandler = bleManagerEmitter.addListener(
        "BleManagerDisconnectPeripheral",
        (event: BleDisconnectPeripheralEvent) => {
          if (event.peripheral == device?.peripheral) {
            setDevice(null);
            Toast.show({ type: "info", text1: `Device ${device?.peripheral} disconnected.` });
            navigation.popToTop();
          }
        },
      );
    }
    return () => {
      messageHandler?.remove();
      disconnectHandler?.remove();
    };
  }, [device]);

  return (
    <GestureHandlerRootView>
      <ReanimatedGraph
        ref={graphRef}
        xAxis={xData}
        yAxis={yData}
        animated={false}
        type="line"
        showExtremeValues={false}
        color={lineColor}
      />
    </GestureHandlerRootView>
  );
}

const colorScheme = Appearance.getColorScheme();
const lineColor = colorScheme === "dark" ? "#FFFFFF" : "#000000";
const styles = StyleSheet.create({});

export default ECGSignalView;
