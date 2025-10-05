import { LightningElement, track } from 'lwc';

const SOCIAL_SECURITY_RATE = 0.062;
const MEDICARE_RATE        = 0.029;

const fedTaxBrackets = [
  { minIncome: 0,      maxIncome: 11925,   rate: 0.10 },
  { minIncome: 11925,  maxIncome: 48475,   rate: 0.12 },
  { minIncome: 48475,  maxIncome: 103350,  rate: 0.22 },
  { minIncome: 103350, maxIncome: 197300,  rate: 0.24 },
  { minIncome: 197300, maxIncome: 250525,  rate: 0.32 },
  { minIncome: 250525, maxIncome: 626350,  rate: 0.35 },
  { minIncome: 626350, maxIncome: Infinity, rate: 0.37 }
];

export default class SalaryCalculator extends LightningElement {
  // input
  @track grossSalary = 0;
  netIncome = 0;
  federalWithholding = 0;
  taxableIncome = 0;
  effectiveTaxRate = 0; // percent as number, e.g., 22.5
  marginalTaxRate = 0;  // percent as number, e.g., 24.0
  socialSecurity = 0;
  medicare = 0;

  // live update
  handleChange(event) {
    const { value } = event.target;

    if (value === '' || value === null) {
      this.grossSalary = null;
      this.resetOutputs();
      return;
    }

    const n = Number(value);
    if (Number.isFinite(n) && n >= 0) {
      this.grossSalary = n;
      this.calculateNetIncome();
    } else {
      this.grossSalary = null;
      this.resetOutputs();
    }
    console.log('handleChange fired', event.target.value);
  }

  resetOutputs() {
    this.netIncome = null;
    this.federalWithholding = null;
    this.taxableIncome = null;
    this.effectiveTaxRate = null;
    this.marginalTaxRate = null;
    this.socialSecurity = null;
    this.medicare = null;
  }

  calculateNetIncome() {
    const g = this.grossSalary;
    if (g == null) {
      this.resetOutputs();
      return;
    }

    // --- Federal (progressive) ---
    let federalTax = 0;
    let marginalRate = 0;

    for (const b of fedTaxBrackets) {
      if (g > b.minIncome) {
        const upper = Math.min(g, b.maxIncome);
        const taxableInBracket = Math.max(0, upper - b.minIncome);
        federalTax += taxableInBracket * b.rate;

        if (g <= b.maxIncome) {
          marginalRate = b.rate;
          break;
        }
      } else {
        break;
      }
    }

    // --- FICA ---
    const socialSecurity = g * SOCIAL_SECURITY_RATE;
    const medicare = g * MEDICARE_RATE;

    // --- Totals ---
    const taxableIncome = g - (socialSecurity + medicare);
    const netIncome = g - (federalTax + socialSecurity + medicare);
    const effectiveTaxRate = g > 0 ? (federalTax / g) : 0;

    // Save (keep as numbers; your template formats them)
    this.federalWithholding = federalTax;
    this.socialSecurity = socialSecurity;
    this.medicare = medicare;
    this.taxableIncome = taxableIncome;
    this.netIncome = netIncome;
    this.effectiveTaxRate = effectiveTaxRate; // e.g., 22.53
    this.marginalTaxRate = marginalRate * 100; // e.g., 24.0
  }

  // If you prefer showing % with a percent sign:
  // get effectiveRateDecimal() {
  //   return this.effectiveTaxRate == null ? null : this.effectiveTaxRate / 10;
  // }
  // get marginalRateDecimal() {
  //   return this.marginalTaxRate == null ? null : this.marginalTaxRate / 100;
  // }
  
}
