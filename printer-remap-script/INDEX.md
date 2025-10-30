# Printer Remapping Solution - Documentation Index

## 🚀 Start Here

**New to this project?** → [CHOOSE-YOUR-METHOD.md](CHOOSE-YOUR-METHOD.md)

**Want to get started fast?** → [QUICKSTART.md](QUICKSTART.md)

**Need the complete overview?** → [SUMMARY.md](SUMMARY.md)

## 📚 Documentation Files

### Getting Started
| File | Description | Read Time |
|------|-------------|-----------|
| **CHOOSE-YOUR-METHOD.md** | Decision guide to pick deployment method | 5 min |
| **QUICKSTART.md** | Fast setup guide (5-10 minutes) | 10 min |
| **SUMMARY.md** | Complete package overview | 15 min |
| **README.md** | Basic project overview | 5 min |

### Advanced
| File | Description | Read Time |
|------|-------------|-----------|
| **DEPLOYMENT-GUIDE.md** | Comprehensive deployment documentation | 30 min |
| **INDEX.md** | This file | 2 min |

## 🛠️ Script Files

### Desktop Deployment
| File | Purpose | When to Use |
|------|---------|-------------|
| **RemapPrinters.ps1** | Basic version with GUI | Simple deployments |
| **RemapPrinters-Enhanced.ps1** | Full-featured with reporting | Production use ⭐ |
| **PrinterConfig.json** | Basic configuration | Testing |
| **PrinterConfig-Enhanced.json** | Advanced config with reporting | Production use ⭐ |

### Enterprise Deployment
| File | Purpose | When to Use |
|------|---------|-------------|
| **Datto-PrinterRemapComponent.ps1** | Datto RMM component | MSP environments |
| **Intune-Detection.ps1** | Intune detection script | M365 environments ⭐ |
| **Intune-Remediation.ps1** | Intune remediation script | M365 environments ⭐ |

### Server-Side (Optional)
| File | Purpose | When to Use |
|------|---------|-------------|
| **Webhook-Handler.ps1** | Central webhook processor | Advanced setups |
| **Autotask-Integration.ps1** | Autotask PSA integration | Server-side only |
| **ITGlue-Integration.ps1** | IT Glue documentation | Server-side only |

⚠️ **Important:** Never deploy server-side scripts to endpoints! They contain API integrations.

## 🎯 Quick Navigation by Task

### "I want to deploy to user desktops"
1. Read [QUICKSTART.md](QUICKSTART.md) - Desktop section
2. Edit `PrinterConfig-Enhanced.json`
3. Deploy `RemapPrinters-Enhanced.ps1`
4. ⏱️ 5 minutes

### "I want to deploy via Datto RMM"
1. Read [DEPLOYMENT-GUIDE.md](DEPLOYMENT-GUIDE.md) - Datto section
2. Edit `Datto-PrinterRemapComponent.ps1`
3. Create custom fields in Datto
4. Upload as component
5. ⏱️ 15 minutes

### "I want to deploy via Intune"
1. Read [DEPLOYMENT-GUIDE.md](DEPLOYMENT-GUIDE.md) - Intune section
2. Edit `Intune-Detection.ps1` and `Intune-Remediation.ps1`
3. Create remediation in Intune
4. Assign to device group
5. ⏱️ 10 minutes

### "I want usage analytics"
1. Use Desktop Script with `RemapPrinters-Enhanced.ps1`
2. Enable usage tracking in config
3. View reports at configured network path
4. See [QUICKSTART.md](QUICKSTART.md) - Usage Analytics section

### "I want email integration"
1. Use Desktop Script with `RemapPrinters-Enhanced.ps1`
2. Configure SMTP settings in `PrinterConfig-Enhanced.json`
3. Set `OnlyEmailOnFailure: true` to avoid spam
4. Emails go to helpdesk automatically

### "I'm not sure which method to use"
1. Read [CHOOSE-YOUR-METHOD.md](CHOOSE-YOUR-METHOD.md)
2. Use the decision tree
3. Compare features table
4. Pick your method
5. Jump to relevant documentation

## 📖 Reading Order Recommendations

### For IT Managers
1. [SUMMARY.md](SUMMARY.md) - Understand what you're getting
2. [CHOOSE-YOUR-METHOD.md](CHOOSE-YOUR-METHOD.md) - Pick deployment method
3. [QUICKSTART.md](QUICKSTART.md) - Get started
4. [DEPLOYMENT-GUIDE.md](DEPLOYMENT-GUIDE.md) - Reference as needed

### For Technicians
1. [QUICKSTART.md](QUICKSTART.md) - Get started fast
2. [CHOOSE-YOUR-METHOD.md](CHOOSE-YOUR-METHOD.md) - Understand options
3. [DEPLOYMENT-GUIDE.md](DEPLOYMENT-GUIDE.md) - Troubleshooting reference

### For MSPs
1. [SUMMARY.md](SUMMARY.md) - Package overview
2. [DEPLOYMENT-GUIDE.md](DEPLOYMENT-GUIDE.md) - Datto RMM section
3. [QUICKSTART.md](QUICKSTART.md) - Quick reference

### For Intune Admins
1. [CHOOSE-YOUR-METHOD.md](CHOOSE-YOUR-METHOD.md) - Confirm Intune is right choice
2. [DEPLOYMENT-GUIDE.md](DEPLOYMENT-GUIDE.md) - Intune section
3. [QUICKSTART.md](QUICKSTART.md) - Quick reference

## 🎓 Learning Path

### Level 1: Understanding (30 min)
1. Read [README.md](README.md)
2. Read [SUMMARY.md](SUMMARY.md)
3. Read [CHOOSE-YOUR-METHOD.md](CHOOSE-YOUR-METHOD.md)

### Level 2: Basic Deployment (1 hour)
1. Choose your method
2. Read [QUICKSTART.md](QUICKSTART.md)
3. Deploy to test computer
4. Validate functionality

### Level 3: Production Deployment (2 hours)
1. Read [DEPLOYMENT-GUIDE.md](DEPLOYMENT-GUIDE.md)
2. Deploy to pilot group
3. Monitor reports
4. Roll out to production

### Level 4: Optimization (Ongoing)
1. Review usage analytics
2. Optimize printer configurations
3. Set up automated workflows
4. Train users as needed

## 🔍 Search by Keyword

### Configuration
- Printer setup → [QUICKSTART.md](QUICKSTART.md)
- SMTP settings → [QUICKSTART.md](QUICKSTART.md)
- JSON config → `PrinterConfig-Enhanced.json`

### Deployment
- Desktop → [QUICKSTART.md](QUICKSTART.md)
- Datto RMM → [DEPLOYMENT-GUIDE.md](DEPLOYMENT-GUIDE.md)
- Intune → [DEPLOYMENT-GUIDE.md](DEPLOYMENT-GUIDE.md)

### Reporting
- CSV reports → [QUICKSTART.md](QUICKSTART.md)
- Usage tracking → [QUICKSTART.md](QUICKSTART.md)
- Email → [QUICKSTART.md](QUICKSTART.md)

### Troubleshooting
- Script won't run → [DEPLOYMENT-GUIDE.md](DEPLOYMENT-GUIDE.md)
- Printers not installing → [DEPLOYMENT-GUIDE.md](DEPLOYMENT-GUIDE.md)
- Email not sending → [DEPLOYMENT-GUIDE.md](DEPLOYMENT-GUIDE.md)

### Security
- API keys → [SUMMARY.md](SUMMARY.md) - Security section
- Webhook → [DEPLOYMENT-GUIDE.md](DEPLOYMENT-GUIDE.md)
- Best practices → [SUMMARY.md](SUMMARY.md)

## 📊 Feature Matrix

| Feature | Desktop | Datto | Intune | Doc Reference |
|---------|---------|-------|--------|---------------|
| GUI | ✅ | ❌ | ❌ | QUICKSTART.md |
| Auto-run | ❌ | ✅ | ✅ | DEPLOYMENT-GUIDE.md |
| Self-healing | ❌ | ❌ | ✅ | DEPLOYMENT-GUIDE.md |
| Usage tracking | ✅ | ❌ | ❌ | QUICKSTART.md |
| CSV reports | ✅ | ❌ | ❌ | QUICKSTART.md |
| Email helpdesk | ✅ | ❌ | ❌ | QUICKSTART.md |

## 🆘 Help & Support

### Common Questions
→ See [QUICKSTART.md](QUICKSTART.md) - Questions section

### Troubleshooting
→ See [DEPLOYMENT-GUIDE.md](DEPLOYMENT-GUIDE.md) - Troubleshooting section

### Configuration Help
→ See [QUICKSTART.md](QUICKSTART.md) - Configuration section

### Deployment Issues
→ See [DEPLOYMENT-GUIDE.md](DEPLOYMENT-GUIDE.md) - Your deployment method section

## 📋 Checklist for First Deployment

- [ ] Read [CHOOSE-YOUR-METHOD.md](CHOOSE-YOUR-METHOD.md)
- [ ] Pick deployment method
- [ ] Read relevant section in [QUICKSTART.md](QUICKSTART.md)
- [ ] Edit configuration file
- [ ] Test on one computer
- [ ] Verify reports are generated
- [ ] Check email functionality (if using)
- [ ] Deploy to pilot group (5-10 users)
- [ ] Monitor for 1 week
- [ ] Review usage analytics
- [ ] Full rollout

## 🎯 Next Steps

1. **First time here?** → [CHOOSE-YOUR-METHOD.md](CHOOSE-YOUR-METHOD.md)
2. **Know what you want?** → [QUICKSTART.md](QUICKSTART.md)
3. **Need details?** → [DEPLOYMENT-GUIDE.md](DEPLOYMENT-GUIDE.md)
4. **Want overview?** → [SUMMARY.md](SUMMARY.md)

---

## 📝 Documentation Maintenance

This documentation was created: 2025-10-31

Last updated: 2025-10-31

Version: 1.0

## 🎉 You're All Set!

This index should help you navigate the complete solution. Start with [CHOOSE-YOUR-METHOD.md](CHOOSE-YOUR-METHOD.md) if you're unsure where to begin.

**Questions?** Check the help sections in each guide.

**Ready to deploy?** Jump to [QUICKSTART.md](QUICKSTART.md) and get started in 5 minutes!
