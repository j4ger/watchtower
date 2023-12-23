import React from "react";
import { StyleSheet } from "react-native";
import { PaperProvider } from "react-native-paper";
import ECGView from "./ECGView";

function App(): React.JSX.Element {
  return (
    <PaperProvider>
      <ECGView />
    </PaperProvider>
  );
}

const styles = StyleSheet.create({});

export default App;
