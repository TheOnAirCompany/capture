# Source of truth for French translations. Regenerates Localizable.xcstrings.
# Usage: python3 scripts/strings.py
import json, pathlib

NB = " "  # French non-breaking space before ? ! :
FR = {
    "Capture": "Capture",
    "Preview": "Aperçu",
    "Screenshots": "Captures d’écran",
    "Videos": "Vidéos",
    "No Device": "Aucun appareil",
    "Connect an iPhone to get started.": "Connectez un iPhone pour commencer.",
    "Connected": "Connecté",
    "No Screenshots Yet": "Aucune capture d’écran",
    "Screenshots you take will appear here.": "Vos captures d’écran apparaîtront ici.",
    "No Videos Yet": "Aucune vidéo",
    "Screen recordings you make will appear here.": "Vos enregistrements vidéo apparaîtront ici.",
    "Camera Access Required": "Accès à la caméra requis",
    "Capture needs camera access to display your iPhone's screen.": "Capture a besoin de l’accès à la caméra pour afficher l’écran de votre iPhone.",
    "Allow Access": "Autoriser l’accès",
    "Open System Settings": "Ouvrir les Réglages Système",
    "Connect your iPhone": "Connectez votre iPhone",
    "Plug your iPhone into this Mac with a USB cable to preview its screen, take screenshots and record videos.": "Branchez votre iPhone à ce Mac avec un câble USB pour prévisualiser son écran, prendre des captures et enregistrer des vidéos.",
    "Need Help?": f"Besoin d’aide{NB}?",
    "Your iPhone doesn't appear?": f"Votre iPhone n’apparaît pas{NB}?",
    "Unlock your iPhone and tap Trust when asked.": f"Déverrouillez votre iPhone et touchez «{NB}Se fier{NB}» si on vous le demande.",
    "Use a data cable: some cables can only charge.": f"Utilisez un câble de données{NB}: certains câbles ne font que charger.",
    "Try unplugging your iPhone and plugging it back in.": "Essayez de débrancher puis de rebrancher votre iPhone.",
    "Back": "Retour",
    "Continue": "Continuer",
    "Get Started": "Commencer",
    "Welcome to Capture": "Bienvenue dans Capture",
    "Take pixel-perfect screenshots and screen recordings of your iPhone, with the clean 9:41 status bar Apple uses in its own product shots.": "Réalisez des captures d’écran et des vidéos impeccables de votre iPhone, avec la barre d’état épurée à 9:41 qu’Apple utilise dans ses propres visuels.",
    "Everything QuickTime does, only faster and more powerful.": "Tout ce que fait QuickTime, en plus pratique et plus complet.",
    "Built for clean iPhone captures": "Pensé pour des captures iPhone impeccables",
    "Capture your iPhone screen in one click, at full native resolution.": "Capturez l’écran de votre iPhone en un clic, en pleine résolution.",
    "Screen Recordings": "Capture vidéo",
    "Record videos with sound, straight from your iPhone.": "Enregistrez des vidéos avec le son, directement depuis votre iPhone.",
    "A Perfect Status Bar": "Une barre d’état parfaite",
    "9:41, full battery and full signal. Automatically, with no notifications.": "9:41, batterie pleine et réseau au maximum. Automatiquement, sans notifications.",
    "Device Frames": "Cadres d’appareil",
    "Add an iPhone frame to your captures when you edit them.": "Ajoutez un cadre d’iPhone à vos captures lors de l’édition.",
    "Recents": "Récents",
    "Find all your captures in one place.": "Retrouvez toutes vos captures au même endroit.",
    "Allow Camera Access": "Autorisez l’accès à la caméra",
    "macOS treats your iPhone's screen like a camera. Capture needs this access to display and record it.": "macOS considère l’écran de votre iPhone comme une caméra. Capture a besoin de cet accès pour l’afficher et l’enregistrer.",
    "Your captures never leave your Mac.": "Vos captures ne quittent jamais votre Mac.",
    "Access granted": "Accès autorisé",
    "Screenshot": "Capture d’écran",
    "Record Video": "Capture vidéo",
    "Stop Recording": "Arrêter l’enregistrement",
    "Take Screenshot": "Prendre une capture d’écran",
    "Open Capture Folder": "Ouvrir le dossier Capture",
    "Couldn't Save the Capture": "Impossible d’enregistrer la capture",
    "OK": "OK",
    "Choose": "Choisir",
    "Choose where to save your screenshots and videos.": "Choisissez où enregistrer vos captures d’écran et vidéos.",
    "Choose Where to Save": "Choisissez où enregistrer",
    "Your screenshots and videos will be saved in this folder.": "Vos captures d’écran et vidéos seront enregistrées dans ce dossier.",
    "Change…": "Modifier…",
    "Capture can't access this folder. Choose another one, or allow access in System Settings > Privacy & Security > Files and Folders.": "Capture ne peut pas accéder à ce dossier. Choisissez-en un autre, ou autorisez l’accès dans Réglages Système > Confidentialité et sécurité > Fichiers et dossiers.",
    "No image has been received from the iPhone yet.": "Aucune image n’a encore été reçue de l’iPhone.",
    "The file could not be written.": "Le fichier n’a pas pu être enregistré.",
    "Access was denied. You can turn it on in System Settings > Privacy & Security > Camera.": "L’accès a été refusé. Vous pouvez l’activer dans Réglages Système > Confidentialité et sécurité > Caméra.",
}

INFO_PLIST_FR = {
    "NSCameraUsageDescription": "Capture utilise l’accès à la caméra pour afficher et enregistrer l’écran de votre iPhone connecté.",
}

def catalog(entries):
    return {
        "sourceLanguage": "en",
        "strings": {
            key: {"localizations": {"fr": {"stringUnit": {"state": "translated", "value": value}}}}
            for key, value in sorted(entries.items())
        },
        "version": "1.0",
    }

root = pathlib.Path(__file__).resolve().parent.parent / "Capture" / "Resources"
for name, entries in [("Localizable", FR), ("InfoPlist", INFO_PLIST_FR)]:
    path = root / f"{name}.xcstrings"
    path.write_text(json.dumps(catalog(entries), ensure_ascii=False, indent=2) + "\n")
    print(f"Wrote {len(entries)} strings to {path.name}")
