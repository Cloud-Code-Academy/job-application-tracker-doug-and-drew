import { LightningElement, track} from 'lwc';

    const socialSecurityRate = 0.062;
    const medicareWithholdingRate = 0.0145;
    const fedTaxBrackets = [
        {minIncome: 0, maxIncome: 11925, rate: 0.10},
        {minIncome: 11926, maxIncome: 48475, rate: 0.12},
        {minIncome: 48476, maxIncome: 103350, rate: 0.22},
        {minIncome: 103351, maxIncome: 197300, rate: 0.24},
        {minIncome: 197301, maxIncome: 250525, rate: 0.32},
        {minIncome: 250526, maxIncome: 626350, rate: 0.35},
        {minIncome: 626351, maxIncome: Infinity, rate: 0.37}
    ];  

export default class TaxCalculator extends LightningElement {

    @track grossSalary = 0;
    @track netIncome = 0;
    totalTax = 0;
    federalRate = 0;
    federalTaxes = 0;
    formattedSalary = 0;
    taxableIncome = 0;
    effectiveTaxRate = 0;
    marginalTaxRate = 0;

    updateSalary(event){
        this.grossSalary = event.target.value;
        this.formattedSalary = `${parseInt(this.grossSalary).toLocaleString()}`;
        this.calculateNetIncome();
    }
    calculateNetIncome(){
        let federalTax = 0;
        for (const bracket of fedTaxBrackets){
            if(this.grossSalary > bracket.minIncome && this.grossSalary <= bracket.maxIncome){
                federalTax += (bracket.rate * this.grossSalary) - (bracket.minIncome * bracket.rate);
                this.federalWithholding = federalTax.toLocaleString(undefined, {maximumFractionDigits: 0});
            }
        }

        // Calculate social security Rate
        this.socialSecurityRate = (this.grossSalary * socialSecurityWithholding).toLocaleString(undefined, {maximumFractionDigits: 0});
        // Calculate netIncome
        this.netIncome = this.grossSalary - (federalTax + parseInt(this.socialSecurityRate) + parsefloat(medicareWithholdingRate));

        // Other values
        this.netIncome = this.netIncome.toLocaleString(undefined, {maximumFractionDigits: 0});
        this.federalTaxes = federalTax.toLocaleString(undefined, {maximumFractionDigits: 0});
        this.taxableIncome = (this.grossSalary - (parseInt(this.socialSecurityRate) + parsefloat(medicareWithholdingRate))).toLocaleString(undefined, {maximumFractionDigits: 0});
        this.effectiveTaxRate = ((federalTax / this.grossSalary) * 100).toLocaleString(undefined, {maximumFractionDigits: 2});
        this.marginalTaxRate = (federalTax / this.grossSalary).toLocaleString(undefined, {maximumFractionDigits: 2});
    }

    resetValues(event){
        const inputValues = event.target.value.trim();

        if ( inputValues === '' || isNaN(inputValues) || parseInt(inputValues) < 0) {
        this.grossSalary = 0;
        this.netIncome = 0;
        this.totalTax = 0;
        this.federalRate = 0;
        this.federalTaxes = 0;
        this.formattedSalary = 0;
        this.taxableIncome = 0;
        this.effectiveTaxRate = 0;
        this.marginalTaxRate = 0;
        } else if (!isNaN(inputValues) && parseInt(inputValues) >= 0) {
            this.grossSalary = parseInt(inputValues);
            this.calculateNetIncome(event.target.value);
        }
    
    }
}