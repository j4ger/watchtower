import { NativeStackNavigationProp } from "@react-navigation/native-stack";
import React, { useContext, useEffect, useState } from "react";
import {
  ActivityIndicator,
  NativeEventEmitter,
  NativeModules,
  PermissionsAndroid,
  Platform,
  StyleSheet,
} from "react-native";
import BleManager, {
  BleDisconnectPeripheralEvent,
  BleManagerDidUpdateValueForCharacteristicEvent,
  BleScanCallbackType,
  BleScanMatchMode,
  BleScanMode,
  Peripheral,
} from "react-native-ble-manager";
import { Button, IconButton, List, Modal, Portal, Snackbar, Surface, Text } from "react-native-paper";
import { RootStackParamList } from "../App";
import { DeviceContext, DeviceContextType } from "../utils/device";

const SECONDS_TO_SCAN_FOR = 3;
const SERVICE_UUIDS: string[] = [];
const ALLOW_DUPLICATES = true;

const TARGET_SERVICE = "ab28c19b-566c-4b1d-a742-14cf91110224";
const TARGET_CHARACTERISTIC = "dea1b85b-d7d4-48d4-abb1-33b7da1b7af5";

const BleManagerModule = NativeModules.BleManager;
const bleManagerEmitter = new NativeEventEmitter(BleManagerModule);

declare module "react-native-ble-manager" {
  // enrich local contract with custom state properties needed by App.tsx
  interface Peripheral {
    connected?: boolean;
    connecting?: boolean;
  }
}

type Props = { navigation: NativeStackNavigationProp<RootStackParamList, "Bluetooth"> };

function BluetoothView({ navigation }: Props): React.JSX.Element {
  let { device, setDevice } = useContext(DeviceContext) as DeviceContextType;

  const [modal, setModal] = useState<{ message: string; animate: boolean } | null>(null);
  const openModal = (message: string, animate: boolean) => {
    setModal({ message, animate });
  };
  const closeModal = () => {
    setModal(null);
  };

  const [snack, setSnack] = useState<string | null>(null);
  const openSnack = (message: string) => {
    setSnack(message);
  };
  const closeSnack = () => {
    setSnack(null);
  };

  const [isScanning, setIsScanning] = useState(false);
  const [peripherals, setPeripherals] = useState(
    new Map<Peripheral["id"], Peripheral>(),
  );

  // console.debug('peripherals map updated', [...peripherals.entries()]);

  const startScan = () => {
    if (!isScanning) {
      // reset found peripherals before scan
      setPeripherals(new Map<Peripheral["id"], Peripheral>());

      try {
        // console.debug("[startScan] starting scan...");
        setIsScanning(true);
        BleManager.scan(SERVICE_UUIDS, SECONDS_TO_SCAN_FOR, ALLOW_DUPLICATES, {
          matchMode: BleScanMatchMode.Sticky,
          scanMode: BleScanMode.LowLatency,
          callbackType: BleScanCallbackType.AllMatches,
        })
          .then(() => {
            // console.debug("[startScan] scan promise returned successfully.");
          })
          .catch((error: any) => {
            openSnack(`Error occurred while scanning BLE: ${error}`);
            console.error("[startScan] ble scan returned in error", error);
          });
      } catch (error) {
        openSnack(`Error occurred while scanning BLE: ${error}`);
        console.error("[startScan] ble scan error thrown", error);
      }
    }
  };

  const handleStopScan = () => {
    setIsScanning(false);
    // console.debug("[handleStopScan] scan is stopped.");
  };

  const handleDisconnectedPeripheral = (
    event: BleDisconnectPeripheralEvent,
  ) => {
    // console.debug(
    //   `[handleDisconnectedPeripheral][${event.peripheral}] disconnected.`,
    // );
    setPeripherals(map => {
      let p = map.get(event.peripheral);
      if (p) {
        p.connected = false;
        return new Map(map.set(event.peripheral, p));
      }
      return map;
    });
  };

  const handleConnectPeripheral = (event: any) => {
    openSnack(`${event.peripheral.name} connected.`);
    console.log(`[handleConnectPeripheral][${event.peripheral}] connected.`);
  };

  const handleUpdateValueForCharacteristic = (
    data: BleManagerDidUpdateValueForCharacteristicEvent,
  ) => {
    // console.debug(
    //   `[handleUpdateValueForCharacteristic] received data from '${data.peripheral}' with characteristic='${data.characteristic}' and value='${data.value}'`,
    // );
  };

  const handleDiscoverPeripheral = (peripheral: Peripheral) => {
    // console.debug("[handleDiscoverPeripheral] new BLE peripheral=", peripheral);
    if (!peripheral.name) {
      peripheral.name = "NO NAME";
    }
    setPeripherals(map => {
      return new Map(map.set(peripheral.id, peripheral));
    });
  };

  const retrieveConnected = async () => {
    try {
      const connectedPeripherals = await BleManager.getConnectedPeripherals();
      if (connectedPeripherals.length === 0) {
        console.warn("[retrieveConnected] No connected peripherals found.");
        return;
      }

      // console.debug(
      //   "[retrieveConnected] connectedPeripherals",
      //   connectedPeripherals,
      // );

      for (var i = 0; i < connectedPeripherals.length; i++) {
        var peripheral = connectedPeripherals[i];
        setPeripherals(map => {
          let p = map.get(peripheral.id);
          if (p) {
            p.connected = true;
            return new Map(map.set(p.id, p));
          }
          return map;
        });
      }
    } catch (error) {
      console.error(
        "[retrieveConnected] unable to retrieve connected peripherals.",
        error,
      );
    }
  };

  const connectPeripheral = async (peripheral: Peripheral) => {
    openModal(`Connecting to ${peripheral.name}...`, true);
    try {
      if (peripheral) {
        setPeripherals(map => {
          let p = map.get(peripheral.id);
          if (p) {
            p.connecting = true;
            return new Map(map.set(p.id, p));
          }
          return map;
        });

        await BleManager.connect(peripheral.id);
        // console.debug(`[connectPeripheral][${peripheral.id}] connected.`);
        openModal(`${peripheral.name} connected. Setting up...`, true);

        setPeripherals(map => {
          let p = map.get(peripheral.id);
          if (p) {
            p.connecting = false;
            p.connected = true;
            return new Map(map.set(p.id, p));
          }
          return map;
        });

        // before retrieving services, it is often a good idea to let bonding & connection finish properly
        await sleep(900);

        /* Test read current RSSI value, retrieve services first */
        const peripheralData = await BleManager.retrieveServices(peripheral.id);
        // console.debug(
        //   `[connectPeripheral][${peripheral.id}] retrieved peripheral services`,
        //   peripheralData,
        // );

        const rssi = await BleManager.readRSSI(peripheral.id);
        // console.debug(
        //   `[connectPeripheral][${peripheral.id}] retrieved current RSSI value: ${rssi}.`,
        // );

        let validDevice = null;

        if (peripheralData.characteristics) {
          for (let characteristic of peripheralData.characteristics) {
            if (characteristic.descriptors) {
              for (let descriptor of characteristic.descriptors) {
                try {
                  let data = await BleManager.readDescriptor(
                    peripheral.id,
                    characteristic.service,
                    characteristic.characteristic,
                    descriptor.uuid,
                  );
                  // console.debug(
                  //   `[connectPeripheral][${peripheral.id}] ${characteristic.service} ${characteristic.characteristic} ${descriptor.uuid} descriptor read as:`,
                  //   data,
                  // );
                  if (
                    characteristic.service == TARGET_SERVICE && characteristic.characteristic == TARGET_CHARACTERISTIC
                  ) {
                    validDevice = {
                      peripheral: peripheral.id,
                      characteristic: characteristic.characteristic,
                      service: characteristic.service,
                    };
                  }
                } catch (error) {
                  console.error(
                    `[connectPeripheral][${peripheral.id}] failed to retrieve descriptor ${descriptor} for characteristic ${characteristic}:`,
                    error,
                  );
                }
              }
            }
          }
        }

        closeModal();

        setPeripherals(map => {
          let p = map.get(peripheral.id);
          if (p) {
            p.rssi = rssi;
            return new Map(map.set(p.id, p));
          }
          return map;
        });
        if (!validDevice) {
          openSnack("Invalid device.");
          BleManager.disconnect(peripheral.id);
        } else {
          setDevice(validDevice);
          await BleManager.startNotification(
            validDevice!.peripheral,
            validDevice!.service,
            validDevice!.characteristic,
          );
          navigation.push("ECGSignal");
        }
      }
    } catch (error) {
      closeModal();
      console.error(
        `[connectPeripheral][${peripheral.id}] connectPeripheral error`,
        error,
      );
    }
  };

  function sleep(ms: number) {
    return new Promise<void>(resolve => setTimeout(resolve, ms));
  }

  useEffect(() => {
    try {
      openModal("Starting BleManager...", true);
      BleManager.start({ showAlert: false })
        .then(() => {
          closeModal();
          // console.debug("BleManager started.");
        })
        .catch((error: any) => {
          openModal(`Unexpected error starting BleManager: ${error}`, false);
          console.error("BeManager could not be started.", error);
        });
    } catch (error) {
      openModal(`Unexpected error starting BleManager: ${error}`, false);
      console.error("unexpected error starting BleManager.", error);
      return;
    }

    const listeners = [
      bleManagerEmitter.addListener(
        "BleManagerDiscoverPeripheral",
        handleDiscoverPeripheral,
      ),
      bleManagerEmitter.addListener("BleManagerStopScan", handleStopScan),
      bleManagerEmitter.addListener(
        "BleManagerDisconnectPeripheral",
        handleDisconnectedPeripheral,
      ),
      bleManagerEmitter.addListener(
        "BleManagerDidUpdateValueForCharacteristic",
        handleUpdateValueForCharacteristic,
      ),
      bleManagerEmitter.addListener(
        "BleManagerConnectPeripheral",
        handleConnectPeripheral,
      ),
    ];

    handleAndroidPermissions();

    return () => {
      // console.debug("[app] main component unmounting. Removing listeners...");
      for (const listener of listeners) {
        listener.remove();
      }
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const handleAndroidPermissions = () => {
    if (Platform.OS === "android" && Platform.Version >= 31) {
      PermissionsAndroid.requestMultiple([
        PermissionsAndroid.PERMISSIONS.BLUETOOTH_SCAN,
        PermissionsAndroid.PERMISSIONS.BLUETOOTH_CONNECT,
      ]).then(result => {
        if (result) {
          // console.debug(
          //   "[handleAndroidPermissions] User accepts runtime permissions android 12+",
          // );
        } else {
          openModal("Bluetooth permissions are required in order to connect to peripherals.", false);
          console.error(
            "[handleAndroidPermissions] User refuses runtime permissions android 12+",
          );
        }
      });
    } else if (Platform.OS === "android" && Platform.Version >= 23) {
      PermissionsAndroid.check(
        PermissionsAndroid.PERMISSIONS.ACCESS_FINE_LOCATION,
      ).then(checkResult => {
        if (checkResult) {
          // console.debug(
          //   "[handleAndroidPermissions] runtime permission Android <12 already OK",
          // );
        } else {
          PermissionsAndroid.request(
            PermissionsAndroid.PERMISSIONS.ACCESS_FINE_LOCATION,
          ).then(requestResult => {
            if (requestResult) {
              // console.debug(
              //   "[handleAndroidPermissions] User accepts runtime permission android <12",
              // );
            } else {
              openModal("Bluetooth permissions are required in order to connect to peripherals.", false);
              console.error(
                "[handleAndroidPermissions] User refuses runtime permission android <12",
              );
            }
          });
        }
      });
    }
  };

  const onSelectDevice = (peripheral: Peripheral) => {
    console.log("Selected " + peripheral.name);
    connectPeripheral(peripheral);
  };

  return (
    <>
      <Button
        icon={isScanning ? "" : "reload"}
        mode="contained"
        style={styles.button}
        onPress={startScan}
        disabled={isScanning}
      >
        {isScanning ? "Scanning..." : "Scan Bluetooth"}
      </Button>

      <Button icon="view-list" mode="outlined" onPress={retrieveConnected}>
        {"Retrieve connected peripherals"}
      </Button>

      <List.Section>
        <List.Subheader style={styles.align}>
          <ActivityIndicator animating={isScanning} />
          Peripherals
        </List.Subheader>
        {Array.from(peripherals.entries()).map(([key, peripheral]) => (
          <List.Item
            key={peripheral.id}
            onPress={() => onSelectDevice(peripheral)}
            title={
              <>
                <Text>{peripheral.name ?? "Unnamed Device"}</Text>
              </>
            }
            description={
              <>
                <Text>{key}</Text>
              </>
            }
            left={props => (
              <>
                <List.Icon
                  {...props}
                  icon={peripheral.connected
                    ? "bluetooth-connect"
                    : peripheral.connecting
                    ? "bluetooth-settings"
                    : peripheral.advertising.serviceUUIDs?.includes(TARGET_SERVICE)
                    ? "watch"
                    : "bluetooth"}
                />
              </>
            )}
            right={props => (
              <>
                {peripheral.connected
                  ? (
                    <IconButton
                      icon="close-box"
                      onPress={() => BleManager.disconnect(peripheral.id)}
                    />
                  )
                  : null}
              </>
            )}
          />
        ))}
      </List.Section>
      <Portal>
        <Modal visible={modal != null} dismissable={false}>
          <Surface style={styles.surface} elevation={5}>
            <ActivityIndicator animating={modal?.animate} />
            <Text>
              {modal?.message}
            </Text>
          </Surface>
        </Modal>
      </Portal>
      <Snackbar visible={snack != null} onDismiss={closeSnack} action={{ label: "OK", onPress: closeSnack }}>
        {snack}
      </Snackbar>
    </>
  );
}

const styles = StyleSheet.create({
  button: {
    marginBottom: 2,
  },
  align: {
    alignContent: "center",
  },
  surface: {
    padding: 4,
    marginHorizontal: 10,
    alignItems: "center",
    justifyContent: "center",
    minHeight: 80,
    borderRadius: 4,
  },
});

export default BluetoothView;
