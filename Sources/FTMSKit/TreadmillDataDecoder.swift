import Foundation

/// Parser für die FTMS Treadmill Data Characteristic `0x2ACD`.
///
/// Zustandslos und ohne CoreBluetooth-Abhängigkeit — damit vollständig
/// unit-testbar gegen synthetische Nutzlasten und echte Hex-Dumps.
public enum TreadmillDataDecoder {

    /// Spec-Sentinel »Data Not Available« (FTMS v1.0, Abschnitte 4.4.1.5 ff.).
    /// Betroffen sind Inclination, Ramp Angle, Total Energy, Energy per Hour,
    /// Energy per Minute, Force on Belt und Power Output.
    enum NichtVerfuegbar {
        static let sint16: Int16 = 0x7FFF      // 32767
        static let uint16: UInt16 = 0xFFFF     // 65535
        static let uint8: UInt8 = 0xFF         // 255
    }

    /// Dekodiert eine `0x2ACD`-Notification.
    ///
    /// - Parameter skalierung: gerätespezifische Auflösungen; Default = Spec.
    /// - Throws: ``FTMSDekodierFehler`` bei zu kurzer Nutzlast.
    public static func dekodiere(
        _ daten: Data,
        skalierung: FTMSSkalierung = .spec
    ) throws -> LaufbandDaten {
        guard daten.count >= 2 else {
            throw FTMSDekodierFehler.flagsUnvollstaendig(laenge: daten.count)
        }

        var leser = ByteLeser(daten)
        let flags = TreadmillFlags(rohwert: try leser.uint16("Flags"))
        var ergebnis = LaufbandDaten(flags: flags, rohbytes: daten)

        // Reihenfolge ist zwingend die Bit-Reihenfolge der Flags.
        if flags.momentanGeschwindigkeitVorhanden {
            ergebnis.momentanGeschwindigkeit =
                Double(try leser.uint16("Instantaneous Speed")) / skalierung.geschwindigkeit
        }
        if flags.durchschnittGeschwindigkeitVorhanden {
            ergebnis.durchschnittGeschwindigkeit =
                Double(try leser.uint16("Average Speed")) / skalierung.geschwindigkeit
        }
        if flags.gesamtDistanzVorhanden {
            // ⚠️ uint24, nicht uint16.
            ergebnis.gesamtDistanz = try leser.uint24("Total Distance")
        }
        if flags.neigungUndRampenwinkelVorhanden {
            let neigungRoh = try leser.int16("Inclination")
            if neigungRoh == NichtVerfuegbar.sint16 {
                ergebnis.nichtVerfuegbareFelder.append("Inclination")
            } else {
                ergebnis.neigung = Double(neigungRoh) / skalierung.neigung
            }

            let winkelRoh = try leser.int16("Ramp Angle Setting")
            if winkelRoh == NichtVerfuegbar.sint16 {
                ergebnis.nichtVerfuegbareFelder.append("Ramp Angle Setting")
            } else {
                ergebnis.rampenwinkel = Double(winkelRoh) / skalierung.neigung
            }
        }
        if flags.hoehengewinnVorhanden {
            ergebnis.hoehengewinnPositiv =
                Double(try leser.uint16("Positive Elevation Gain")) / skalierung.hoehengewinn
            ergebnis.hoehengewinnNegativ =
                Double(try leser.uint16("Negative Elevation Gain")) / skalierung.hoehengewinn
        }
        if flags.momentanPaceVorhanden {
            ergebnis.momentanPace =
                Double(try leser.uint8("Instantaneous Pace")) / skalierung.pace
        }
        if flags.durchschnittPaceVorhanden {
            ergebnis.durchschnittPace =
                Double(try leser.uint8("Average Pace")) / skalierung.pace
        }
        if flags.energieVorhanden {
            let gesamtRoh = try leser.uint16("Total Energy")
            if gesamtRoh == NichtVerfuegbar.uint16 {
                ergebnis.nichtVerfuegbareFelder.append("Total Energy")
            } else {
                ergebnis.gesamtEnergie = gesamtRoh
            }

            let proStundeRoh = try leser.uint16("Energy per Hour")
            if proStundeRoh == NichtVerfuegbar.uint16 {
                ergebnis.nichtVerfuegbareFelder.append("Energy per Hour")
            } else {
                ergebnis.energieProStunde = proStundeRoh
            }

            // Spec nennt hier 0xFF und schreibt im Fließtext irrtümlich
            // »decimal value of 257 in UINT16«. Das Feld ist uint8, Sentinel 255.
            let proMinuteRoh = try leser.uint8("Energy per Minute")
            if proMinuteRoh == NichtVerfuegbar.uint8 {
                ergebnis.nichtVerfuegbareFelder.append("Energy per Minute")
            } else {
                ergebnis.energieProMinute = proMinuteRoh
            }
        }
        if flags.herzfrequenzVorhanden {
            ergebnis.herzfrequenz = try leser.uint8("Heart Rate")
        }
        if flags.metabolischesAequivalentVorhanden {
            ergebnis.metabolischesAequivalent =
                Double(try leser.uint8("Metabolic Equivalent")) / skalierung.metabolischesAequivalent
        }
        if flags.verstricheneZeitVorhanden {
            ergebnis.verstricheneZeit = try leser.uint16("Elapsed Time")
        }
        if flags.verbleibendeZeitVorhanden {
            ergebnis.verbleibendeZeit = try leser.uint16("Remaining Time")
        }
        if flags.kraftUndLeistungVorhanden {
            let kraftRoh = try leser.int16("Force on Belt")
            if kraftRoh == NichtVerfuegbar.sint16 {
                ergebnis.nichtVerfuegbareFelder.append("Force on Belt")
            } else {
                ergebnis.kraftAufBand = kraftRoh
            }

            let leistungRoh = try leser.int16("Power Output")
            if leistungRoh == NichtVerfuegbar.sint16 {
                ergebnis.nichtVerfuegbareFelder.append("Power Output")
            } else {
                ergebnis.leistung = leistungRoh
            }
        }

        ergebnis.ueberschuessigeBytes = leser.rest
        return ergebnis
    }

    /// Bequemlichkeit für Tests und Forensik an echten Dumps: `"0801f4..."`.
    public static func dekodiere(
        hex: String,
        skalierung: FTMSSkalierung = .spec
    ) throws -> LaufbandDaten {
        try dekodiere(Data(hex: hex), skalierung: skalierung)
    }
}

public extension Data {
    /// Erzeugt Data aus Hex-String. Trennzeichen (Leerzeichen, `:`, `-`) sind erlaubt.
    /// Ungültige Zeichen werden ignoriert; ein einzelnes übriges Nibble entfällt.
    init(hex: String) {
        let bereinigt = hex.replacingOccurrences(of: "0x", with: "")
                           .replacingOccurrences(of: "0X", with: "")
        let ziffern = bereinigt.compactMap { $0.hexDigitValue }
        var bytes: [UInt8] = []
        bytes.reserveCapacity(ziffern.count / 2)
        var index = 0
        while index + 1 < ziffern.count {
            bytes.append(UInt8(ziffern[index] << 4 | ziffern[index + 1]))
            index += 2
        }
        self = Data(bytes)
    }

    /// Kompakter Hex-String für das Raw-Debug-Log.
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
