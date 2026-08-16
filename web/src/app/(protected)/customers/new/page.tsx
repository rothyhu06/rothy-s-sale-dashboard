import{Divider,SectionHeader}from"@/components/design-system";import{CustomerForm}from"@/features/customers/components/customer-form";
export default function NewCustomerPage(){return <div className="grid gap-8"><SectionHeader level={1} title="New Customer" description="Capture stable, verifiable institution facts."/><Divider/><CustomerForm/></div>}
