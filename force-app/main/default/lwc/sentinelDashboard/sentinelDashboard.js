import { LightningElement, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getOverview from '@salesforce/apex/SentinelDashboardController.getOverview';

export default class SentinelDashboard extends LightningElement {
    scope = 'all';
    overview;
    error;
    _wired;

    @wire(getOverview, { ownerScope: '$scope' })
    wiredOverview(result) {
        this._wired = result;
        if (result.data) {
            this.overview = result.data;
            this.error = undefined;
        } else if (result.error) {
            this.error = result.error;
            this.overview = undefined;
        }
    }

    get loading() {
        return !this.overview && !this.error;
    }
    get hasData() {
        return this.overview && this.overview.objects && this.overview.objects.length > 0;
    }
    get showEmpty() {
        return this.overview && (!this.overview.objects || this.overview.objects.length === 0);
    }
    get total() {
        return this.overview ? this.overview.totalAtRisk : 0;
    }
    get criticalTotal() {
        return this.overview ? this.overview.critical : 0;
    }
    get objectCount() {
        return this.overview ? this.overview.objectCount : 0;
    }
    get errorMessage() {
        if (!this.error) return '';
        return this.error.body ? this.error.body.message : this.error.message;
    }

    get allBtnClass() {
        return 'sen-toggle__btn' + (this.scope === 'all' ? ' is-active' : '');
    }
    get mineBtnClass() {
        return 'sen-toggle__btn' + (this.scope === 'mine' ? ' is-active' : '');
    }

    get cards() {
        if (!this.hasData) return [];
        return this.overview.objects.map((o, i) => {
            const total = o.staleCount || 0;
            const pct = (n) => (total > 0 ? Math.round(((n || 0) / total) * 100) : 0);
            const agingPct = pct(o.aging);
            const stalePct = pct(o.stale);
            const criticalPct = pct(o.critical);

            let dominant = 'aging';
            if (o.critical > 0 && o.critical >= o.stale && o.critical >= o.aging) {
                dominant = 'critical';
            } else if (o.stale > 0 && o.stale >= o.aging) {
                dominant = 'stale';
            }

            const owners = (o.topOwners || []).slice(0, 3).map((g) => ({
                key: g.key,
                count: g.count
            }));

            return {
                key: o.objectApiName,
                label: o.label,
                objectApiName: o.objectApiName,
                staleCount: total,
                thresholdDays: o.thresholdDays,
                aging: o.aging || 0,
                stale: o.stale || 0,
                critical: o.critical || 0,
                agingStyle: `width:${agingPct}%`,
                staleStyle: `width:${stalePct}%`,
                criticalStyle: `width:${criticalPct}%`,
                cardClass: `sen-card sen-card--${dominant}`,
                accentClass: `sen-accent sen-accent--${dominant}`,
                delayStyle: `animation-delay:${i * 80}ms`,
                owners
            };
        });
    }

    handleAll() {
        this.scope = 'all';
    }
    handleMine() {
        this.scope = 'mine';
    }
    handleRefresh() {
        return refreshApex(this._wired);
    }
}
