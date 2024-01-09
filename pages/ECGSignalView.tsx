import { NativeStackNavigationProp } from "@react-navigation/native-stack";
import SkiaChart, { SVGRenderer } from "@wuba/react-native-echarts/skiaChart";
import { EChartsOption } from "echarts";
import { LineChart } from "echarts/charts";
import { GridComponent } from "echarts/components";
import * as echarts from "echarts/core";
import React, { useContext, useEffect, useRef, useState } from "react";
import {
  Appearance,
  EmitterSubscription,
  NativeEventEmitter,
  NativeModules,
  StyleSheet,
  useColorScheme,
} from "react-native";
import { BleDisconnectPeripheralEvent, BleManagerDidUpdateValueForCharacteristicEvent } from "react-native-ble-manager";
import { GestureHandlerRootView } from "react-native-gesture-handler";
import { Toast } from "react-native-toast-message/lib/src/Toast";
import { RootStackParamList } from "../App";
import { BLEData, decodePacket } from "../utils/BLEData";
import { DeviceContext, DeviceContextType } from "../utils/Device";

const BUFFER_SIZE = 600;
const BLANK_SIZE = 50;
const LINE_COLOR = "green";
const DELAY_MS = 2;
const MAX_QUEUE = 500;

const BleManagerModule = NativeModules.BleManager;
const bleManagerEmitter = new NativeEventEmitter(BleManagerModule);

type Props = { navigation: NativeStackNavigationProp<RootStackParamList, "ECGSignal"> };

function ECGSignalView({ navigation }: Props): React.JSX.Element {
  echarts.use([SVGRenderer, LineChart, GridComponent]);

  const chartRef = useRef<typeof SkiaChart | null>(null);
  let chart: echarts.ECharts | null = null;

  const data: [number, number][] = [];
  let queue: BLEData[] = [];

  const colorScheme = useColorScheme();

  useEffect(() => {
    let i = 0;
    while (i < BUFFER_SIZE) {
      data.push([i, 0]);
      i++;
    }
    const option: EChartsOption = {
      animation: false,
      xAxis: {
        type: "value",
        show: false,
      },
      yAxis: {
        type: "value",
        show: false,
        min: -1,
        max: 2,
      },
      series: [
        {
          name: "prev",
          data: data,
          type: "line",
          showSymbol: false,
          color: LINE_COLOR,
        },
        {
          name: "next",
          data: [],
          type: "line",
          showSymbol: false,
          color: LINE_COLOR,
        },
      ],
    };

    const newChart = echarts.init(chartRef.current, colorScheme, {
      renderer: "svg",
      width: 400,
      height: 400,
    });
    newChart.setOption(option);
    chart = newChart;
    return () => newChart.dispose();
  }, []);

  let { device, setDevice } = useContext(DeviceContext) as DeviceContextType;

  let messageHandler: EmitterSubscription | null = null;
  let disconnectHandler: EmitterSubscription | null = null;
  useEffect(() => {
    // TODO: go back to first page when disconnect
    if (device) {
      messageHandler = bleManagerEmitter.addListener(
        "BleManagerDidUpdateValueForCharacteristic",
        async (event: BleManagerDidUpdateValueForCharacteristicEvent) => {
          if (
            event.peripheral == device?.peripheral && event.service == device?.service
            && event.characteristic == device.characteristic
          ) {
            const bleData = decodePacket(event.value);
            // console.debug(`Decoded data: {timestamp: ${bleData.timestamp}, value: ${bleData.value}}`);
            queue = [...queue, ...bleData];
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

  useEffect(() => {
    const interval = setInterval(() => {
      if (queue.length > MAX_QUEUE) {
        queue = [];
        Toast.show({ type: "error", text1: "Can't keep up. Too much data!" });
        return;
      }
      if (queue.length > 0) {
        const newData = queue.shift()!;
        let cursor = newData.timestamp % BUFFER_SIZE;
        data[cursor] = [cursor, newData.value];

        const prev = data.slice(cursor + BLANK_SIZE);
        const next = data.slice(0, cursor);

        chart?.setOption({
          series: [
            { name: "prev", data: prev },
            { name: "next", data: next },
          ],
        });
      }
    }, DELAY_MS);
    return () => clearInterval(interval);
  }, []);

  return (
    <GestureHandlerRootView style={{ flex: 1 }}>
      <SkiaChart ref={chartRef} />
    </GestureHandlerRootView>
  );
}

const colorScheme = Appearance.getColorScheme();
const styles = StyleSheet.create({});

export default ECGSignalView;
