import { LightningElement, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getPipelineValue from '@salesforce/apex/SentinelDashboardController.getPipelineValue';

function formatCurrency(n) {
    const val = n || 0;
    return '$' + Math.round(val).toLocaleString('en-US');
}

export default class SentinelPipelineValue extends LightningElement {
    pipeline;
    error;
    _wired;

    @wire(getPipelineValue)
    wiredPipeline(result) {
        this._wired = result;
        if (result.data) {
            this.pipeline = result.data;
            this.error = undefined;
        } else if (result.error) {
            this.error = result.error;
            this.pipeline = undefined;
        }
    }

    get loading() {
        return !this.pipeline && !this.error;
    }
    get hasData() {
        return !!this.pipeline;
    }
    get errorMessage() {
        if (!this.error) return '';
        return this.error.body ? this.error.body.message : this.error.message;
    }

    get totalFormatted() {
        return this.hasData ? formatCurrency(this.pipeline.totalAmount) : '$0';
    }
    get criticalFormatted() {
        return this.hasData ? formatCurrency(this.pipeline.criticalAmount) : '$0';
    }
    get staleFormatted() {
        return this.hasData ? formatCurrency(this.pipeline.staleAmount) : '$0';
    }
    get agingFormatted() {
        return this.hasData ? formatCurrency(this.pipeline.agingAmount) : '$0';
    }

    get stageRows() {
        if (!this.hasData || !this.pipeline.byStage) return [];
        const sorted = [...this.pipeline.byStage].sort((a, b) => (b.amount || 0) - (a.amount || 0));
        const max = Math.max(1, ...sorted.map((s) => s.amount || 0));
        return sorted.map((s, i) => ({
            key: s.stage + i,
            stage: s.stage,
            count: s.count,
            amountFormatted: formatCurrency(s.amount),
            barStyle: `width:${Math.round(((s.amount || 0) / max) * 100)}%`
        }));
    }

    handleRefresh() {
        return refreshApex(this._wired);
    }
}
