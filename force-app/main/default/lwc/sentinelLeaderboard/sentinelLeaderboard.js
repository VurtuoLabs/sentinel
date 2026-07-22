import { LightningElement, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getLeaderboard from '@salesforce/apex/SentinelDashboardController.getLeaderboard';

export default class SentinelLeaderboard extends LightningElement {
    leaderboard;
    error;
    _wired;

    @wire(getLeaderboard, { objectApiName: null })
    wiredLeaderboard(result) {
        this._wired = result;
        if (result.data) {
            this.leaderboard = result.data;
            this.error = undefined;
        } else if (result.error) {
            this.error = result.error;
            this.leaderboard = undefined;
        }
    }

    get loading() {
        return !this.leaderboard && !this.error;
    }
    get hasData() {
        return !!(this.leaderboard && this.leaderboard.length > 0);
    }
    get showEmpty() {
        return !!(this.leaderboard && this.leaderboard.length === 0);
    }
    get errorMessage() {
        if (!this.error) return '';
        return this.error.body ? this.error.body.message : this.error.message;
    }
    get total() {
        if (!this.hasData) return 0;
        return this.leaderboard.reduce((sum, g) => sum + (g.count || 0), 0);
    }

    get rows() {
        if (!this.hasData) return [];
        const max = Math.max(1, ...this.leaderboard.map((g) => g.count || 0));
        return this.leaderboard.map((g, i) => ({
            key: g.key + i,
            owner: g.key,
            count: g.count,
            barStyle: `width:${Math.round(((g.count || 0) / max) * 100)}%`,
            rank: i + 1
        }));
    }

    handleRefresh() {
        return refreshApex(this._wired);
    }
}
