// ==============================================================================
// IT-Command-Hub x AutoSec-Hardener : Module de Durcissement & Audit (ANSSI / CIS)
// ==============================================================================
// Instructions :
// 1. Ajoutez la nouvelle catégorie dans votre liste de catégories IT-Command-Hub :
//    { id: 'autosec', label: 'Sécurité & Hardening (ANSSI)', icon: 'shield-check', count: 6, badge: 'CIS/ANSSI' }
// 2. Insérez les commandes ci-dessous dans votre tableau 'commands' (data/commands.js).
// ==============================================================================

const autosecCommands = [
  // 1. Audit Windows
  {
    id: 'autosec-win-audit',
    title: 'Audit de Sécurité Windows (ANSSI / CIS Benchmark)',
    category: 'autosec',
    type: 'powershell',
    adminRequired: true,
    command: 'powershell -ExecutionPolicy Bypass -File "{autosec_path}\\windows\\Audit-Security.ps1" -JsonExport',
    description: 'Vérifie 8 contrôles critiques de conformité (SMBv1, LLMNR, SMB Signing, NTLMv2, LSA Protection, Pare-feu 3 profils, ScriptBlock Logging) et génère un export JSON avec score sur 100%.',
    parameters: [
      {
        key: 'autosec_path',
        label: 'Chemin du dossier autosec-hardening',
        defaultValue: 'C:\\autosec-hardening'
      }
    ],
    tags: ['anssi', 'cis', 'audit', 'securite', 'compliance', 'score', 'json']
  },

  // 2. Durcissement Windows
  {
    id: 'autosec-win-hardening',
    title: 'Appliquer le Durcissement Sécurisé Windows',
    category: 'autosec',
    type: 'powershell',
    adminRequired: true,
    command: 'powershell -ExecutionPolicy Bypass -File "{autosec_path}\\windows\\Apply-Hardening.ps1"',
    description: 'Sauvegarde automatique du Registre (dans C:\\WindowsBackups_AutoSec_*) et durcissement complet : désactive SMBv1/LLMNR, force SMB Signing, NTLMv2 niveau 5, active LSA RunAsPPL et le pare-feu.',
    parameters: [
      {
        key: 'autosec_path',
        label: 'Chemin du dossier autosec-hardening',
        defaultValue: 'C:\\autosec-hardening'
      }
    ],
    tags: ['hardening', 'durcissement', 'lsa', 'smb', 'firewall', 'mimikatz', 'backup']
  },

  // 3. Rollback Windows
  {
    id: 'autosec-win-rollback',
    title: 'Restauration Sécurité Windows (Rollback 1-Clic)',
    category: 'autosec',
    type: 'powershell',
    adminRequired: true,
    command: 'powershell -ExecutionPolicy Bypass -File "{autosec_path}\\windows\\Rollback-Security.ps1"',
    description: 'Restaure automatiquement la dernière sauvegarde du registre et réactive les paramètres Windows antérieurs au durcissement.',
    parameters: [
      {
        key: 'autosec_path',
        label: 'Chemin du dossier autosec-hardening',
        defaultValue: 'C:\\autosec-hardening'
      }
    ],
    tags: ['rollback', 'restauration', 'undo', 'urgence', 'registre']
  },

  // 4. Comparaison Avant / Après
  {
    id: 'autosec-compare-reports',
    title: 'Générer un Rapport de Comparaison Avant/Après (PDF & Markdown)',
    category: 'autosec',
    type: 'powershell',
    adminRequired: false,
    command: 'powershell -ExecutionPolicy Bypass -File "{autosec_path}\\tools\\Compare-Reports.ps1" -Before "{rapport_avant}" -After "{rapport_apres}" -Pdf',
    description: 'Analyse deux audits JSON (avant/après durcissement), calcule le différentiel de score, liste les vulnérabilités corrigées et génère un rapport PDF imprimable.',
    parameters: [
      {
        key: 'autosec_path',
        label: 'Chemin du dossier autosec-hardening',
        defaultValue: 'C:\\autosec-hardening'
      },
      {
        key: 'rapport_avant',
        label: 'Fichier JSON initial',
        defaultValue: 'C:\\autosec-hardening\\reports\\windows\\audit_avant.json'
      },
      {
        key: 'rapport_apres',
        label: 'Fichier JSON final',
        defaultValue: 'C:\\autosec-hardening\\reports\\windows\\audit_apres.json'
      }
    ],
    tags: ['rapport', 'comparaison', 'pdf', 'diff', 'metrics']
  },

  // 5. Audit Docker (CIS Benchmark)
  {
    id: 'autosec-docker-audit',
    title: 'Audit Conteneurs Docker (CIS Docker Benchmark)',
    category: 'autosec',
    type: 'powershell',
    adminRequired: true,
    command: 'wsl bash -c "sudo {autosec_linux_path}/docker/audit_docker.sh --json"',
    description: 'Exécute l\'audit CIS Docker via WSL ou environnement Linux distant : vérifie l\'API démon, conteneurs root, limites de ressources et signature d\'images.',
    parameters: [
      {
        key: 'autosec_linux_path',
        label: 'Chemin Unix du projet dans WSL',
        defaultValue: '/mnt/c/autosec-hardening'
      }
    ],
    tags: ['docker', 'cis', 'conteneurs', 'supply-chain', 'wsl']
  },

  // 6. Playbook Complet Automatisé
  {
    id: 'autosec-playbook-full-cycle',
    title: '⚡ Playbook : Cycle Complet Durcissement & Certification',
    category: 'playbooks',
    type: 'powershell',
    adminRequired: true,
    command: '# Étape 1 : Audit Initial\npowershell -ExecutionPolicy Bypass -File "{autosec_path}\\windows\\Audit-Security.ps1" -JsonExport\n# Étape 2 : Application du Durcissement avec Backup\npowershell -ExecutionPolicy Bypass -File "{autosec_path}\\windows\\Apply-Hardening.ps1"\n# Étape 3 : Audit de Validation Post-Durcissement\npowershell -ExecutionPolicy Bypass -File "{autosec_path}\\windows\\Audit-Security.ps1" -JsonExport',
    description: 'Enchaîne l\'audit initial, le durcissement complet avec sauvegarde, et l\'audit final de conformité pour attester du score à 100%.',
    steps: [
      '1. Exécution de l\'audit initial et enregistrement du score de départ',
      '2. Sauvegarde des clés de registre critiques dans C:\\WindowsBackups_AutoSec_*',
      '3. Application des 8 mesures de durcissement (SMB, NTLM, LSA, Pare-feu)',
      '4. Validation post-durcissement et calcul du score de conformité final'
    ],
    parameters: [
      {
        key: 'autosec_path',
        label: 'Chemin du dossier autosec-hardening',
        defaultValue: 'C:\\autosec-hardening'
      }
    ],
    tags: ['playbook', 'audit', 'durcissement', 'automatisation', 'anssi']
  }
];

if (typeof module !== 'undefined' && module.exports) {
  module.exports = autosecCommands;
}
