import { NativeStackNavigationProp } from "@react-navigation/native-stack";
import React, { useContext, useEffect, useMemo, useState } from "react";
import { EmitterSubscription, NativeEventEmitter, NativeModules, StyleSheet } from "react-native";
import { BleDisconnectPeripheralEvent, BleManagerDidUpdateValueForCharacteristicEvent } from "react-native-ble-manager";
import { LineChart } from "react-native-gifted-charts";
import { FAB, Portal } from "react-native-paper";
import { Toast } from "react-native-toast-message/lib/src/Toast";
import { RootStackParamList } from "../App";
import { decodePacket } from "../utils/BLEData";
import { DeviceContext, DeviceContextType } from "../utils/device";

const BUFFER_SIZE = 30;

const BleManagerModule = NativeModules.BleManager;
const bleManagerEmitter = new NativeEventEmitter(BleManagerModule);

type Props = { navigation: NativeStackNavigationProp<RootStackParamList, "ECGSignal"> };

function ECGSignalView({ navigation }: Props): React.JSX.Element {
  const randomData = () => {
    const buffer = new Array<{ value: number }>();
    let i = 0;
    while (i < BUFFER_SIZE) {
      buffer.push({ value: Math.random() * 100 });
      i++;
    }
    return buffer;
  };

  const [data, setData] = useState(randomData);
  const pushData = (newData: number) => {
    setData(oldValue => [...oldValue.slice(1), { value: newData }]);
  };

  const [FABState, setFABState] = useState({ open: false });
  const { open } = FABState;

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
            console.debug(`Decoded data: {timestamp: ${bleData.timestamp}, value: ${bleData.value}}`);
            pushData(bleData.value);
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
    <>
      <LineChart
        data={data}
        color={"#65B741"}
        // dataPointsColor={"#1A5D1A"}
        hideDataPoints
        hideYAxisText
        hideRules
        thickness={5}
        initialSpacing={0}
        spacing={10}
        isAnimated={true}
        // animateOnDataChange={true}
      />
      <Portal>
        <FAB.Group
          style={styles.fab}
          open={open}
          visible
          icon={open ? "layers-triple-outline" : "layers-triple"}
          actions={[
            {
              icon: "plus-box",
              label: "Add Sample Data",
              onPress: () => pushData(Math.random() * 100),
            },
            { icon: "refresh", label: "Randomize Data", onPress: () => setData(randomData) },
          ]}
          onStateChange={({ open }) => setFABState({ open })}
          onPress={() => {
            if (open) setFABState({ open: false });
            else setFABState({ open: true });
          }}
        />
      </Portal>
    </>
  );
}

const styles = StyleSheet.create({
  fab: {
    position: "absolute",
    margin: 15,
    right: 0,
    bottom: 0,
  },
});

export default ECGSignalView;
