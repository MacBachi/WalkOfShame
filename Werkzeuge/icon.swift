#!/usr/bin/env swift
// ⚠️ Nicht mehr die Quelle des App-Icons. Seit 18.08.2026 liegt dort eine
// gelieferte Grafik (siehe CONTEXT.md); ein Aufruf mit dem Pfad unten würde sie
// überschreiben. Das Skript bleibt als geometrische Alternative erhalten.
//
// Zeichnet ein App-Icon "Walk of Shame" als 1024x1024-PNG.
//
//   swift Werkzeuge/icon.swift App/Treadmill/Assets.xcassets/AppIcon.appiconset/icon.png
//
// Bewusst als Code und nicht als Binärdatei im Repo: so lässt sich das Motiv
// nachvollziehen und ändern, ohne ein Grafikprogramm zu öffnen.
//
// Konvention: alle Koordinaten sind Anteile der Kantenlänge, y zählt **von
// unten** — also wie in CoreGraphics. Nur eine Konvention, damit die Figur
// nicht versehentlich auf dem Kopf steht.

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let kante = 1024.0
let ziel = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"

let raum = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(data: nil, width: Int(kante), height: Int(kante),
                          bitsPerComponent: 8, bytesPerRow: 0, space: raum,
                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
    fatalError("Kontext ließ sich nicht anlegen")
}

func farbe(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> CGColor {
    CGColor(colorSpace: raum, components: [r/255, g/255, b/255, a])!
}
func p(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: kante * x, y: kante * y) }
func laenge(_ anteil: Double) -> Double { kante * anteil }

let nacht   = farbe(38, 26, 66)
let daemmer = farbe(126, 58, 106)
let morgen  = farbe(255, 146, 84)
let sonne   = farbe(255, 206, 112)
let dunkel  = farbe(24, 18, 34)
let hell    = farbe(255, 253, 248)
let schuh   = farbe(255, 74, 110)

// MARK: - Hintergrund

let verlauf = CGGradient(colorsSpace: raum,
                         colors: [nacht, daemmer, morgen] as CFArray,
                         locations: [0, 0.5, 1])!
// Ohne die beiden Optionen bleibt alles außerhalb der Verlaufsachse
// unbemalt — und damit schwarz.
ctx.drawLinearGradient(verlauf, start: p(0, 1), end: p(0.35, 0),
                       options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])

// Aufgehende Sonne — die Tageszeit, zu der man den Walk of Shame antritt.
ctx.setFillColor(sonne.copy(alpha: 0.92)!)
let sonnenradius = laenge(0.345)
ctx.fillEllipse(in: CGRect(x: kante * 0.50 - sonnenradius, y: kante * 0.48 - sonnenradius,
                           width: sonnenradius * 2, height: sonnenradius * 2))

// MARK: - Hilfen

func kreis(_ mitte: CGPoint, radius: Double, farbe: CGColor) {
    ctx.setFillColor(farbe)
    ctx.fillEllipse(in: CGRect(x: mitte.x - radius, y: mitte.y - radius,
                               width: radius * 2, height: radius * 2))
}

func gerundetesRechteck(_ rechteck: CGRect, radius: Double, farbe: CGColor) {
    ctx.setFillColor(farbe)
    ctx.addPath(CGPath(roundedRect: rechteck, cornerWidth: radius,
                       cornerHeight: radius, transform: nil))
    ctx.fillPath()
}

// MARK: - Barfuß-Abdrücke
//
// Motivwechsel mit Absicht: eine Strichfigur oder ein Stöckelschuh sind
// *Illustration* — die entsteht nicht dadurch, dass man Kurvenpunkte hinschreibt,
// und die Versuche sahen entsprechend aus. Ein Fußabdruck besteht dagegen aus
// Ellipsen. Das ist eine Form, die Geometrie tatsächlich treffen kann.
//
// Inhaltlich passt es ohnehin besser: barfuß, die Schuhe in der Hand, im
// Morgengrauen — nur eben auf einem Laufband, also ohne von der Stelle zu kommen.

/// Ein Abdruck: Ballen, fünf Zehen, Ferse. `spiegeln` für den anderen Fuß.
func abdruck(mitte: CGPoint, hoehe: Double, drehung: Double, spiegeln: Bool) {
    ctx.saveGState()
    ctx.translateBy(x: mitte.x, y: mitte.y)
    ctx.rotate(by: drehung)
    if spiegeln { ctx.scaleBy(x: -1, y: 1) }

    let h = laenge(hoehe)
    func ellipse(_ x: Double, _ y: Double, _ b: Double, _ hh: Double) {
        ctx.fillEllipse(in: CGRect(x: h * x - h * b / 2, y: h * y - h * hh / 2,
                                   width: h * b, height: h * hh))
    }

    ctx.setFillColor(dunkel)
    ellipse( 0.00,  0.10, 0.48, 0.42)   // Ballen
    ellipse(-0.03, -0.24, 0.34, 0.30)   // Ferse, dicht darunter

    // Zehen liegen dem Ballen an und folgen seiner Rundung
    ellipse(-0.17, 0.345, 0.170, 0.170)
    ellipse(-0.02, 0.375, 0.135, 0.135)
    ellipse( 0.10, 0.355, 0.115, 0.115)
    ellipse( 0.195, 0.320, 0.100, 0.100)
    ellipse( 0.270, 0.275, 0.085, 0.085)

    ctx.restoreGState()
}

// Zwei Schritte, versetzt und leicht ansteigend — Richtung Sonne.
abdruck(mitte: p(0.375, 0.395), hoehe: 0.30, drehung: -0.14, spiegeln: true)
abdruck(mitte: p(0.615, 0.545), hoehe: 0.30, drehung:  0.10, spiegeln: false)

// MARK: - Schreiben

guard let bild = ctx.makeImage() else { fatalError("Bild ließ sich nicht erzeugen") }
let url = URL(fileURLWithPath: ziel)
try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                         withIntermediateDirectories: true)
guard let senke = CGImageDestinationCreateWithURL(url as CFURL,
                                                  UTType.png.identifier as CFString, 1, nil) else {
    fatalError("Datei ließ sich nicht anlegen")
}
CGImageDestinationAddImage(senke, bild, nil)
CGImageDestinationFinalize(senke)
print("geschrieben: \(url.path)")
