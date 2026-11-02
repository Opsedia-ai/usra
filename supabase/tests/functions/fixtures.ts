// Shared test data.

export const validReport = {
  findings: [{
    member: "P2",
    severity: "orange",
    title: "Two paracetamol products at the same time",
    why: "Panadol and Adol are both active this week and contain the same ingredient.",
    evidence: ["med_81", "med_92"],
    action: "Ask your doctor or pharmacist which one to keep.",
  }],
  urgent: false,
  disclaimer: "Not a diagnosis. Talk to your doctor.",
};
