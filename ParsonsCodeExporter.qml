//=============================================================================
//  Parsons Code Exporter Plugin
//  Copyright (C) 2016 Johan Temmerman (jeetee)
//=============================================================================
import QtQuick 2.2
import QtQuick.Controls 1.1
import QtQuick.Dialogs 1.2
import QtQuick.Layouts 1.1
import Qt.labs.folderlistmodel 2.1
import Qt.labs.settings 1.0
//import QtQml 2.2

import MuseScore 1.0
import FileIO 1.0


MuseScore {
	menuPath: "Plugins.Parsons Code Export"
	version: "0.5"
	description: "Save Parsons Code of a voice to a text file."
	pluginType: "dialog"
	//requiresScore: true //not supported before 2.1.0, manual checking onRun

	width:  320
	height: 180

	onRun: {
		if (!curScore) {
			console.log(qsTranslate("QMessageBox", "No score open.\nThis plugin requires an open score to run.\n"));
			Qt.quit();
		}
		fillDropDowns();
	}

	Component.onDestruction: {
		settings.exportDirectory = exportDirectory.text
	}

	function fillDropDowns() {
		//load staff list
		staffList.clear();
		for (var i = 0; i < curScore.parts.length; ++i) {
			var part = curScore.parts[i];
			var nPartStaves = (part.endTrack - part.startTrack) / 4;
			for (var p = 0; p < nPartStaves; ++p) {
				staffList.append({
					text: part.partName + ((nPartStaves > 1)? (' ' + (p + 1)) : ''),
					partName: part.partName,
					partStartTrack: part.startTrack
				});
			}
		}
		//init voices list
		voiceList.clear();
		voiceList.append({ text: qsTranslate("selectionfilter", "Voice 1")/*, voiceOffset: 0*/ });
		voiceList.append({ text: qsTranslate("selectionfilter", "Voice 2")/*, voiceOffset: 1*/ });
		voiceList.append({ text: qsTranslate("selectionfilter", "Voice 3")/*, voiceOffset: 2*/ });
		voiceList.append({ text: qsTranslate("selectionfilter", "Voice 4")/*, voiceOffset: 3*/ });

		directorySelectDialog.folder = ((Qt.platform.os == "windows")? "file:///" : "file://") + exportDirectory.text;
	}

	Settings {
		id: settings
		property alias exportDirectory: exportDirectory.text
	}

	FileIO {
		id: textWriter
		onError: console.log(msg)
	}

	FileDialog {
		id: directorySelectDialog
		title: qsTranslate("MS::PathListDialog", "Choose a directory")
		selectFolder: true
		visible: false
		onAccepted: {
			exportDirectory.text = this.folder.toString().replace("file://", "").replace(/^\/(.:\/)(.*)$/, "$1$2");
		}
		Component.onCompleted: visible = false
	}

	Rectangle {
		color: "lightgrey"
		anchors.fill: parent

		GridLayout {
			columns: 2
			anchors.fill: parent
			anchors.margins: 10

			Label {
				text: qsTranslate("Ms::ScoreView", "Staff") + ": "
			}
			ComboBox {
				id: staffSelection
				model: ListModel {
					id: staffList
					 //dummy ListElement required for initial creation of this component
					ListElement { text: "partName+staff"; partName: "part.partName"; partStartTrack: 0 }
				}
			}

			Label {
				text: qsTranslate("StaffTextProperties", "Voice:")
			}
			ComboBox {
				id: voiceSelection
				model: ListModel {
					id: voiceList
					//dummy ListElement required for initial creation of this component
					ListElement { text: "v1";/* voiceOffset: 0;*/ }
				}
			}

			Button {
				id: selectDirectory
				text: qsTranslate("PrefsDialogBase", "Browse...")
				onClicked: {
					directorySelectDialog.open();
				}
			}
			Label {
				id: exportDirectory
				text: ""
			}
			
			Button {
				id: exportButton
				Layout.columnSpan: 2
				text: qsTranslate("PrefsDialogBase", "Export")
				onClicked: {
					exportParsons();
					Qt.quit();
				}
			}

		}
	}

	function exportParsons()
	{
		//get filename
		var filename = (curScore.title != "")? curScore.title : Date.now();
		filename += ' ' + staffSelection.currentText + ' ' + voiceSelection.currentIndex;
		filename = filename.replace(/ /g, "_");
		filename = exportDirectory.text + "//" + filename + ".txt";
		console.log(filename);
		
		//get the cursor for the selected melody
		var cursor = curScore.newCursor(/*true*/);
		cursor.track = staffList.get(staffSelection.currentIndex).partStartTrack + voiceSelection.currentIndex;
		cursor.rewind(0);
		
		//export
		textWriter.source = filename;
		textWriter.write(getParsons(cursor));
	}
	
	function getParsons(cursor)
	{
		var parsons = "";
		var pitch = undefined;
		var diff = 0;
		
		//find the start note
		while (cursor.segment && cursor.element && (cursor.element.type !== Element.CHORD)) { cursor.next(); }
		if (cursor.segment) {
			//found first note
			parsons += '*';
			pitch = cursor.element.notes[cursor.element.notes.length - 1].ppitch;
			
			//now find the others
			cursor.next();
			while (cursor.segment) {
				if (cursor.element && (cursor.element.type === Element.CHORD)) {
					diff = pitch; //old pitch
					pitch = cursor.element.notes[cursor.element.notes.length - 1].ppitch; //new pitch
					diff -= pitch; //old - new
					parsons += (diff > 0) ? 'D' : ((diff < 0) ? 'U' : 'R');
				}
				cursor.next();
			}
		}
		return parsons;
	}
}
