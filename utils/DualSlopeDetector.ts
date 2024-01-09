class DualSlopeDetector {
    private fs: number;
    private full_scale: number;
    private l_range: number;
    private h_range: number;
    private diff_thres: number;
    private recent_diff: number[];
    private avg_diff: number;
    private avg_upper_limit: number;
    private avg_lower_limit: number;
    private diff_lower_limit: number;
    private recent_peak: number[];
    private avg_peak: number;
    private last_index: number;
    private min_index_delta: number;

    constructor(fs: number = 360, full_scale: number = 2048) {
        this.fs = fs;
        this.full_scale = full_scale;
        this.l_range = Math.floor(0.027 * fs);
        this.h_range = Math.floor(0.063 * fs);
        this.diff_thres = (full_scale * 2.125 / fs);
        this.recent_diff = Array(8).fill(full_scale * 8.125 / fs);
        this.avg_diff = full_scale * 8.125 / fs;
        this.avg_upper_limit = full_scale * 10 / fs;
        this.avg_lower_limit = full_scale * 5 / fs;
        this.diff_lower_limit = full_scale * 0.75 / fs;
        this.recent_peak = Array(8).fill(1.7);
        this.avg_peak = 1.7;
        this.last_index = 0;
        this.min_index_delta = 0.2 * fs;
    }

    detect(source: number[]): number[] {
        const result: number[] = [];

        for (let index = 0; index < source.length; index++) {
            let value = source[index] * 2048;
            let s_l_max: number | null = null;
            let s_l_min: number | null = null;
            let s_r_max: number | null = null;
            let s_r_min: number | null = null;

            for (let i = this.l_range; i < this.h_range; i++) {
                const l_index = index - i;
                const r_index = index + i;

                if (l_index >= 0) {
                    const s_l = (value - source[l_index]) / i;

                    if (s_l_max === null || s_l > s_l_max) {
                        s_l_max = s_l;
                    }

                    if (s_l_min === null || s_l < s_l_min) {
                        s_l_min = s_l;
                    }
                }

                if (r_index < source.length) {
                    const s_r = (value - source[r_index]) / i;

                    if (s_r_max === null || s_r > s_r_max) {
                        s_r_max = s_r;
                    }

                    if (s_r_min === null || s_r < s_r_min) {
                        s_r_min = s_r;
                    }
                }
            }

            if (s_l_max === null || s_r_max === null) {
                continue;
            }

            const s_diff = Math.max(s_r_max - s_l_min, s_l_max - s_r_min);

            if (!(s_diff > this.diff_thres)) {
                continue;
            }

            let s_min: number;

            if (s_l_max - s_r_min > s_r_max - s_l_min) {
                s_min = Math.min(Math.abs(s_l_max), Math.abs(s_r_min));

                if (!(s_min > this.diff_lower_limit && this.sgn(s_l_max) == this.sgn(s_r_min))) {
                    continue;
                }
            } else {
                s_min = Math.min(Math.abs(s_r_max), Math.abs(s_l_min));

                if (!(s_min > this.diff_lower_limit && this.sgn(s_r_max) == this.sgn(s_l_min))) {
                    continue;
                }
            }

            if (!(value > this.avg_peak * 0.4)) {
                continue;
            }

            if (!(index - this.last_index > this.min_index_delta)) {
                if (s_diff > this.recent_diff[7]) {
                    result.pop();
                } else {
                    continue;
                }
            }

            result.push(index);
            value = Math.abs(value);

            let l_index = index - this.h_range;
            if (l_index < 0) {
                l_index = 0;
            }

            let r_index = index + this.h_range;
            if (r_index >= source.length) {
                r_index = source.length - 1;
            }

            for (let i = l_index; i <= r_index; i++) {
                const abs_point = Math.abs(source[i]);

                if (abs_point > value) {
                    value = abs_point;
                    index = i;
                }
            }

            this.recent_diff.shift();
            this.recent_diff.push(s_diff);
            this.avg_diff = this.calculateAverage(this.recent_diff);

            if (this.avg_diff > this.avg_upper_limit) {
                this.diff_thres = 7680 / this.fs;
            } else if (this.avg_diff > this.avg_lower_limit) {
                this.diff_thres = 4352 / this.fs;
            } else {
                this.diff_thres = 3840 / this.fs;
            }

            this.recent_peak.shift();
            this.recent_peak.push(value);
            this.avg_peak = this.calculateAverage(this.recent_peak);
            this.last_index = index;
        }

        return result;
    }

    private sgn(input: number): boolean {
        return input > 0;
    }

    private calculateAverage(values: number[]): number {
        return values.reduce((sum, value) => sum + value, 0) / values.length;
    }
}

export default DualSlopeDetector;
