import { LightningElement, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getTrends from '@salesforce/apex/SentinelDashboardController.getTrends';

export default class SentinelTrends extends LightningElement {
    trends;
    error;
    _wired;

    @wire(getTrends, { daysBack: 14 })
    wiredTrends(result) {
        this._wired = result;
        if (result.data) {
            this.trends = result.data;
            this.error = undefined;
        } else if (result.error) {
            this.error = result.error;
            this.trends = undefined;
        }
    }

    get loading() {
        return !this.trends && !this.error;
    }
    get hasData() {
        return !!(this.trends && this.trends.length > 0);
    }
    get showEmpty() {
        return !!(this.trends && this.trends.length === 0);
    }
    get errorMessage() {
        if (!this.error) return '';
        return this.error.body ? this.error.body.message : this.error.message;
    }

    get rows() {
        if (!this.hasData) return [];
        return this.trends.map((t) => {
            const points = t.points || [];
            const hasEnough = points.length >= 2;
            const latest = points[points.length - 1];
            let staleLine = '';
            let criticalLine = '';
            if (hasEnough) {
                const maxVal = Math.max(1, ...points.map((p) => Math.max(p.staleCount, p.criticalCount)));
                const stepX = 300 / (points.length - 1);
                staleLine = points
                    .map((p, i) => `${Math.round(i * stepX)},${Math.round(90 - (p.staleCount / maxVal) * 80)}`)
                    .join(' ');
                criticalLine = points
                    .map((p, i) => `${Math.round(i * stepX)},${Math.round(90 - (p.criticalCount / maxVal) * 80)}`)
                    .join(' ');
            }
            return {
                key: t.objectApiName,
                label: t.label,
                hasEnough,
                staleLine,
                criticalLine,
                latestStale: latest ? latest.staleCount : 0,
                latestCritical: latest ? latest.criticalCount : 0
            };
        });
    }

    handleRefresh() {
        return refreshApex(this._wired);
    }
}
