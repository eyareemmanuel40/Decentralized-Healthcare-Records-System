# Decentralized Healthcare Records System

A comprehensive blockchain-based healthcare management system built on Stacks using Clarity smart contracts.

## System Overview

This system provides a secure, decentralized platform for managing healthcare records, doctor credentials, prescriptions, and insurance claims. All data is stored on-chain with proper access controls and encryption considerations.

## Contracts

### 1. Patient Identity Verification (`patient-identity.clar`)
- Manages patient registration and identity verification
- Stores encrypted patient demographic data
- Controls access permissions for medical records
- Handles patient consent management

### 2. Medical History Storage (`medical-history.clar`)
- Stores encrypted medical records and history
- Manages medical record access permissions
- Tracks record updates and modifications
- Maintains audit trails for all medical data

### 3. Doctor Credential Validation (`doctor-credentials.clar`)
- Verifies and stores healthcare provider licenses
- Manages doctor registration and certification
- Tracks credential expiration and renewals
- Controls doctor access to patient records

### 4. Prescription Tracking (`prescription-tracking.clar`)
- Manages prescription creation and tracking
- Monitors medication distribution and usage
- Prevents prescription fraud and abuse
- Tracks prescription fulfillment status

### 5. Insurance Claim Verification (`insurance-claims.clar`)
- Automates healthcare payment processing
- Verifies insurance coverage and claims
- Manages claim approval workflows
- Tracks payment status and history

## Features

- **Secure Access Control**: Role-based permissions for patients, doctors, and insurance providers
- **Data Integrity**: Immutable record keeping with audit trails
- **Privacy Protection**: Encrypted data storage with controlled access
- **Fraud Prevention**: Built-in validation and verification mechanisms
- **Automated Processing**: Smart contract automation for claims and prescriptions

## Data Types

- **Patient Records**: Encrypted demographic and medical data
- **Doctor Credentials**: License verification and certification data
- **Prescriptions**: Medication details, dosage, and fulfillment tracking
- **Insurance Claims**: Coverage verification and payment processing
- **Audit Logs**: Comprehensive activity tracking

## Security Features

- Multi-signature requirements for sensitive operations
- Time-based access controls and expiration
- Encrypted data storage with access keys
- Comprehensive audit logging
- Role-based permission system

## Getting Started

1. Install dependencies: \`npm install\`
2. Run tests: \`npm test\`
3. Deploy contracts using Clarinet
4. Configure access permissions
5. Begin patient and doctor registration

## Testing

The system includes comprehensive tests for all contracts using Vitest. Tests cover:
- Contract deployment and initialization
- Access control mechanisms
- Data storage and retrieval
- Error handling and edge cases
- Integration between contracts

## Deployment

Use Clarinet for local development and testing:
\`\`\`
clarinet console
clarinet test
clarinet deploy
\`\`\`

## License

MIT License - See LICENSE file for details

