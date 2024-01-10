import CalcCascades from "fili/src/calcCascades";
import IirFilter from "fili/src/iirFilter";

export const SAMPLE_RATE = 50 * 1000 / 200;

const f1 = 8; // Hz - Fast QRS Detection with an Optimized Knowledge-Based Method
const f2 = 20; // Hz - Fast QRS Detection with an Optimized Knowledge-Based Method

const windowSize = 350; // Size of window to look back on
const downPeriod = 60; // Refractory Period in which another positive will not be generated
const threshold = 0.7; // Threshold of window maximum that must be reached
const beatsLimit = 4;

const iirCalculator = new CalcCascades();

const bandpassCoefficients = iirCalculator.bandpass({
  order: 3,
  characteristic: "butterworth",
  Fs: SAMPLE_RATE,
  Fc: (f2 - f1) / 2 + f1,
  BW: (f2 - f1) / 2,
});

const iirFilter = new IirFilter(bandpassCoefficients);

let risingEdgeFilter: boolean[] = [];

export default (reading: number, buffer: [number, number][]) => {
  const bandpassed = iirFilter.singleStep(reading);
  const bandpassedBuffer = iirFilter.multiStep(buffer.slice(-windowSize).map(([_, reading]) => reading));
  const max = Math.max(...bandpassedBuffer);

  const decision = bandpassed >= max * threshold;

  if (risingEdgeFilter.length === downPeriod) risingEdgeFilter.shift();
  const isRisingEdge = risingEdgeFilter.every(x => !x);
  risingEdgeFilter.push(decision);

  return decision && isRisingEdge ? true : false;
};
