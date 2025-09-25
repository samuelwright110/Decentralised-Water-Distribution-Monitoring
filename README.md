# 💧 Decentralised Water Distribution Monitoring

A blockchain-based smart contract system for monitoring and managing water distribution networks on the Stacks blockchain.

## 📋 Overview

This Clarity smart contract enables decentralized monitoring of water distribution stations with real-time data collection, automated alerts, and comprehensive analytics. Perfect for municipal water systems, private water utilities, and environmental monitoring organizations.

## ✨ Key Features

- 🏭 **Station Registration**: Register water distribution stations with location and capacity data
- 📊 **Real-time Monitoring**: Record flow rates, pressure, pH levels, temperature, and turbidity
- 🔔 **Automated Alerts**: Smart contract generates alerts for abnormal readings
- 👥 **Access Control**: Authorize specific monitors and station operators
- 📈 **Daily Statistics**: Automatic calculation of daily averages
- 🔍 **Data Retrieval**: Query historical readings and station information
- ⚡ **Alert Management**: Create, track, and resolve system alerts

## 🛠️ Installation & Setup

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Node.js and npm (for testing)

### Quick Start

1. Clone the repository:
```bash
git clone <repository-url>
cd Decentralised-Water-Distribution-Monitoring
```

2. Install dependencies:
```bash
npm install
```

3. Check contract syntax:
```bash
clarinet check
```

4. Run tests:
```bash
npm test
```

## 🚀 Usage Guide

### 1. Register a Water Station

```clarity
(contract-call? .Decentralised-Water-Distribution-Monitoring register-station "Main Pump Station" "123 Water St, City" u50000)
```

### 2. Authorize a Monitor

Only the contract owner can authorize monitors:
```clarity
(contract-call? .Decentralised-Water-Distribution-Monitoring authorize-monitor 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)
```

### 3. Record Water Quality Data

Station owners or authorized monitors can record readings:
```clarity
(contract-call? .Decentralised-Water-Distribution-Monitoring record-reading 
  u1           ;; station-id
  u15000       ;; flow-rate (L/min)
  u350         ;; pressure (kPa) 
  u725         ;; ph-level (pH * 100)
  u220         ;; temperature (°C * 10)
  u50          ;; turbidity (NTU)
)
```

### 4. Query Station Information

```clarity
(contract-call? .Decentralised-Water-Distribution-Monitoring get-station u1)
(contract-call? .Decentralised-Water-Distribution-Monitoring get-latest-reading u1)
(contract-call? .Decentralised-Water-Distribution-Monitoring get-station-alerts u1)
```

## 📊 Data Structure

### Station Data
- **name**: Station identifier (max 50 chars)
- **location**: Physical address (max 100 chars)
- **owner**: Principal who registered the station
- **active**: Whether station is operational
- **created-at**: Registration timestamp
- **last-update**: Most recent data update

### Reading Data
- **flow-rate**: Water flow in L/min
- **pressure**: Water pressure in kPa
- **ph-level**: pH value * 100 (for precision)
- **temperature**: Temperature in °C * 10
- **turbidity**: Turbidity in NTU
- **timestamp**: When reading was recorded
- **recorded-by**: Monitor who submitted data

### Alert Types
- 🔴 **LOW_FLOW**: Flow rate below threshold
- ⚠️ **PH_ABNORMAL**: pH outside safe range (6.5-8.5)
- 🟡 **HIGH_TURBIDITY**: Water clarity issues
- 🌡️ **HIGH_TEMP**: Temperature elevation

## 🔧 Configuration

### Alert Thresholds
- **Flow Rate**: Configurable global threshold (default: 5000 L/min)
- **pH Range**: 6.5 - 8.5 (650-850 in contract units)
- **Turbidity**: > 5 NTU triggers alert
- **Temperature**: > 35°C triggers alert

### Modify Thresholds
```clarity
(contract-call? .Decentralised-Water-Distribution-Monitoring set-alert-threshold u4000)
```

## 🔍 Available Functions

### Public Functions

| Function | Description | Access |
|----------|-------------|--------|
| `register-station` | Add new monitoring station | Anyone |
| `authorize-monitor` | Grant monitoring permissions | Contract Owner |
| `revoke-monitor` | Remove monitoring permissions | Contract Owner |
| `record-reading` | Submit sensor data | Station Owner/Monitor |
| `deactivate-station` | Disable a station | Station Owner |
| `resolve-alert` | Mark alert as resolved | Station Owner/Monitor |
| `set-alert-threshold` | Update global thresholds | Contract Owner |

### Read-only Functions

| Function | Description |
|----------|-------------|
| `get-station` | Retrieve station details |
| `get-reading` | Get specific reading data |
| `get-latest-reading` | Most recent station reading |
| `get-station-alerts` | Active alerts for station |
| `get-daily-stats` | Daily average statistics |
| `get-total-stations` | Total registered stations |
| `is-monitor-authorized` | Check monitor status |

## 🧪 Testing

Run comprehensive tests:
```bash
npm test
```

Test specific functionality:
```bash
clarinet test tests/water-monitoring_test.ts
```

## 📈 Analytics & Reporting

The contract automatically tracks:
- 📊 Daily averages for all parameters
- 📋 Historical reading counts per station
- 🚨 Alert history and resolution times
- 👥 Monitor activity and reputation

## 🔐 Security Features

- ✅ **Access Control**: Multi-level permission system
- ✅ **Data Validation**: Input sanitization and range checking
- ✅ **Ownership Verification**: Station owners control their data
- ✅ **Monitor Authorization**: Only approved monitors can submit data

## ⚠️ Error Codes

| Code | Error | Description |
|------|-------|-------------|
| u100 | ERR_UNAUTHORIZED | Insufficient permissions |
| u101 | ERR_STATION_NOT_FOUND | Invalid station ID |
| u102 | ERR_INVALID_DATA | Data outside valid ranges |
| u103 | ERR_STATION_EXISTS | Station already registered |
| u104 | ERR_INVALID_THRESHOLD | Invalid threshold value |



## 📄 License

This project is licensed under the MIT License.


---

Built with ❤️ for transparent water management on the Stacks blockchain 💧⛓️
