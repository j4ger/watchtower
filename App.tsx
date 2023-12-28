import { getHeaderTitle } from "@react-navigation/elements";
import { NavigationContainer } from "@react-navigation/native";
import { createNativeStackNavigator, NativeStackHeaderProps } from "@react-navigation/native-stack";
import React, { useState } from "react";
import { StyleSheet } from "react-native";
import { Appbar, PaperProvider } from "react-native-paper";
import { Toast } from "react-native-toast-message/lib/src/Toast";
import BluetoothView from "./pages/Bluetooth";
import ECGSignalView from "./pages/ECGSignalView";
import { BLEDevice, DeviceContext } from "./utils/device";

export type RootStackParamList = { Bluetooth: undefined; ECGSignal: undefined };

function App(): React.JSX.Element {
  const Stack = createNativeStackNavigator();

  const [device, setDevice] = useState<BLEDevice | null>(null);
  const setDeviceWrapper = (device: BLEDevice | null) => {
    setDevice(device);
  };

  return (
    <DeviceContext.Provider value={{ device, setDevice: setDeviceWrapper }}>
      <PaperProvider>
        <NavigationContainer>
          <Stack.Navigator
            initialRouteName="Bluetooth"
            screenOptions={{
              header: (props) => <HeaderBar {...props} />,
            }}
          >
            <Stack.Screen name="Bluetooth" component={BluetoothView} options={{ title: "Select device" }} />
            <Stack.Screen name="ECGSignal" component={ECGSignalView} options={{ title: "View ECG signal" }} />
          </Stack.Navigator>
        </NavigationContainer>
        <Toast />
      </PaperProvider>
    </DeviceContext.Provider>
  );
}

const styles = StyleSheet.create({});

export default App;

function HeaderBar({
  navigation,
  route,
  options,
  back,
}: NativeStackHeaderProps): React.JSX.Element {
  const title = getHeaderTitle(options, route.name);

  return (
    <Appbar.Header>
      {back ? <Appbar.BackAction onPress={navigation.goBack} /> : null}
      <Appbar.Content title={title} />
    </Appbar.Header>
  );
}
