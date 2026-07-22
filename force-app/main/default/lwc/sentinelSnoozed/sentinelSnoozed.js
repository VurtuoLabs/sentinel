import { LightningElement, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getSnoozed from '@salesforce/apex/SentinelDashboardController.getSnoozed';

export default class SentinelSnoozed extends LightningElement {
    snoozed;
    error;
    _wired;

    @wire(getSnoozed)
    wiredSnoozed(result) {
        this._wired = result;
        if (result.data) {
            this.snoozed = result.data;
            this.error = undefined;
        } else if (result.error) {
            this.error = result.error;
            this.snoozed = undefined;
        }
    }

    get loading() {
        return !this.snoozed && !this.error;
    }
    get hasData() {
        return !!(this.snoozed && this.snoozed.length > 0);
    }
    get showEmpty() {
        return !!(this.snoozed && this.snoozed.length === 0);
    }
    get errorMessage() {
        if (!this.error) return '';
        return this.error.body ? this.error.body.message : this.error.message;
    }

    get rows() {
        if (!this.hasData) return [];
        return this.snoozed.map((s) => ({
            key: s.recordId,
            displayName: s.displayName,
            objectApiName: s.objectApiName,
            reason: s.reason || '(no reason given)',
            snoozedByName: s.snoozedByName || 'Unknown',
            snoozedUntil: s.snoozedUntil,
            daysRemaining: s.daysRemaining,
            urgentClass: s.daysRemaining <= 1 ? 'sz-days sz-days--soon' : 'sz-days'
        }));
    }

    handleRefresh() {
        return refreshApex(this._wired);
    }
}
