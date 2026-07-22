import { LightningElement, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getActivityGaps from '@salesforce/apex/SentinelDashboardController.getActivityGaps';

export default class SentinelActivityGaps extends LightningElement {
    gaps;
    error;
    _wired;

    @wire(getActivityGaps)
    wiredGaps(result) {
        this._wired = result;
        if (result.data) {
            this.gaps = result.data;
            this.error = undefined;
        } else if (result.error) {
            this.error = result.error;
            this.gaps = undefined;
        }
    }

    get loading() {
        return !this.gaps && !this.error;
    }
    get hasData() {
        return !!(this.gaps && this.gaps.length > 0);
    }
    get showEmpty() {
        return !!(this.gaps && this.gaps.length === 0);
    }
    get errorMessage() {
        if (!this.error) return '';
        return this.error.body ? this.error.body.message : this.error.message;
    }

    get rows() {
        if (!this.hasData) return [];
        return this.gaps.map((g) => {
            const total = (g.neverContactedCount || 0) + (g.wentColdCount || 0);
            const neverPct = total > 0 ? Math.round(((g.neverContactedCount || 0) / total) * 100) : 0;
            const coldPct = total > 0 ? 100 - neverPct : 0;
            return {
                key: g.objectApiName,
                label: g.label,
                neverContactedCount: g.neverContactedCount,
                wentColdCount: g.wentColdCount,
                neverStyle: `width:${neverPct}%`,
                coldStyle: `width:${coldPct}%`
            };
        });
    }

    handleRefresh() {
        return refreshApex(this._wired);
    }
}
