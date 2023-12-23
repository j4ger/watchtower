import React, { useState } from "react";
import { StyleSheet, View } from "react-native";
import { LineChart } from "react-native-gifted-charts";
import { Appbar, FAB } from "react-native-paper";

function ECGView(): React.JSX.Element {
  const randomData = () =>
    Array<number>(100).fill(0).map((_) => ({
      value: Math.random() * 10,
    }));

  const [data, setData] = useState(randomData);

  return (
    <View style={styles.container}>
      <Appbar.Header>
        <Appbar.Content title="ECG Signal" />
        <Appbar.Action
          icon="refresh"
          onPress={() => {
            setData(randomData);
          }}
        />
      </Appbar.Header>
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
      />
      <FAB
        icon="plus"
        style={styles.fab}
        onPress={() => {
          setData(oldValue => [...oldValue, { value: Math.random() * 10 }]);
        }}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  fab: {
    position: "absolute",
    margin: 15,
    right: 0,
    bottom: 0,
  },
});

export default ECGView;
