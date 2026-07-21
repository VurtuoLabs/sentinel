import { LightningElement, api } from 'lwc';

export default class SentinelStatCard extends LightningElement {
    @api card;

    get hasOwners() {
        return this.card && this.card.owners && this.card.owners.length > 0;
    }
}
