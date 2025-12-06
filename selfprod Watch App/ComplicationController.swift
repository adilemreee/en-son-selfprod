import ClockKit
import SwiftUI

class ComplicationController: NSObject, CLKComplicationDataSource {
    
    // MARK: - Complication Configuration
    
    func getComplicationDescriptors(handler: @escaping ([CLKComplicationDescriptor]) -> Void) {
        let descriptors = [
            CLKComplicationDescriptor(identifier: "complication", displayName: "Selfprod", supportedFamilies: CLKComplicationFamily.allCases)
        ]
        
        // Call the handler with the currently supported complication descriptors
        handler(descriptors)
    }
    
    func handleSharedComplicationDescriptors(_ complicationDescriptors: [CLKComplicationDescriptor]) {
        // Do any necessary work to support these newly shared complication descriptors
    }
    
    // MARK: - Timeline Configuration
    
    func getTimelineEndDate(for complication: CLKComplication, withHandler handler: @escaping (Date?) -> Void) {
        // We act as a launcher, so no timeline needed.
        handler(nil)
    }
    
    func getPrivacyBehavior(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationPrivacyBehavior) -> Void) {
        handler(.showOnLockScreen)
    }
    
    // MARK: - Timeline Population
    
    func getCurrentTimelineEntry(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTimelineEntry?) -> Void) {
        // create the template immediately
        if let template = getTemplate(for: complication) {
            let entry = CLKComplicationTimelineEntry(date: Date(), complicationTemplate: template)
            handler(entry)
        } else {
            handler(nil)
        }
    }
    
    func getTimelineEntries(for complication: CLKComplication, after date: Date, limit: Int, withHandler handler: @escaping ([CLKComplicationTimelineEntry]?) -> Void) {
        // No future entries needed for a launcher
        handler(nil)
    }
    
    // MARK: - Sample Templates
    
    func getLocalizableSampleTemplate(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTemplate?) -> Void) {
        handler(getTemplate(for: complication))
    }
    
    // MARK: - Helper Methods
    
    private func getTemplate(for complication: CLKComplication) -> CLKComplicationTemplate? {
        let appColor = UIColor(red: 1.0, green: 0.2, blue: 0.6, alpha: 1.0) // Deep Pink
        
        switch complication.family {
        case .circularSmall:
            let template = CLKComplicationTemplateCircularSmallSimpleImage()
            template.imageProvider = CLKImageProvider(onePieceImage: UIImage(systemName: "heart.fill")!)
            template.imageProvider.tintColor = appColor
            return template
            
        case .modularSmall:
            let template = CLKComplicationTemplateModularSmallSimpleImage()
            template.imageProvider = CLKImageProvider(onePieceImage: UIImage(systemName: "heart.fill")!)
            template.imageProvider.tintColor = appColor
            return template
            
        case .modularLarge:
            let template = CLKComplicationTemplateModularLargeStandardBody()
            template.headerTextProvider = CLKSimpleTextProvider(text: "Selfprod")
            template.body1TextProvider = CLKSimpleTextProvider(text: "Seni Özledim")
            template.headerImageProvider = CLKImageProvider(onePieceImage: UIImage(systemName: "heart.fill")!)
            template.headerImageProvider?.tintColor = appColor
            return template
            
        case .utilitarianSmall:
            let template = CLKComplicationTemplateUtilitarianSmallSquare()
            template.imageProvider = CLKImageProvider(onePieceImage: UIImage(systemName: "heart.fill")!)
            template.imageProvider.tintColor = appColor
            return template
            
        case .utilitarianLarge:
            let template = CLKComplicationTemplateUtilitarianLargeFlat()
            template.textProvider = CLKSimpleTextProvider(text: "Selfprod")
            template.imageProvider = CLKImageProvider(onePieceImage: UIImage(systemName: "heart.fill")!)
            template.imageProvider?.tintColor = appColor
            return template
            
        case .graphicCorner:
            let template = CLKComplicationTemplateGraphicCornerCircularImage()
            // Use custom neon asset
            if let image = UIImage(named: "ComplicationHeart") {
                template.imageProvider = CLKFullColorImageProvider(fullColorImage: image)
            } else {
                template.imageProvider = CLKFullColorImageProvider(fullColorImage: UIImage(systemName: "heart.circle.fill")!)
            }
            return template
            
        case .graphicCircular:
            let template = CLKComplicationTemplateGraphicCircularImage()
            if let image = UIImage(named: "ComplicationHeart") {
                template.imageProvider = CLKFullColorImageProvider(fullColorImage: image)
            } else {
                template.imageProvider = CLKFullColorImageProvider(fullColorImage: UIImage(systemName: "heart.fill")!.withTintColor(appColor, renderingMode: .alwaysOriginal))
            }
            return template
            
        case .graphicRectangular:
            let template = CLKComplicationTemplateGraphicRectangularStandardBody()
            template.headerTextProvider = CLKSimpleTextProvider(text: "Selfprod")
            template.body1TextProvider = CLKSimpleTextProvider(text: "Kalp Gönder")
            return template
            
        case .graphicExtraLarge:
             if #available(watchOS 7.0, *) {
                 let template = CLKComplicationTemplateGraphicExtraLargeCircularImage()
                 if let image = UIImage(named: "ComplicationHeart") {
                     template.imageProvider = CLKFullColorImageProvider(fullColorImage: image)
                 } else {
                     template.imageProvider = CLKFullColorImageProvider(fullColorImage: UIImage(systemName: "heart.fill")!.withTintColor(appColor, renderingMode: .alwaysOriginal))
                 }
                 return template
             } else {
                 return nil
             }
            
        default:
            return nil
        }
    }
}
