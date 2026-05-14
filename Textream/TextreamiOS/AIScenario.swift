//
//  AIScenario.swift
//  Textream
//
//  AI script generation scenarios.
//

import Foundation

enum AIScenario: String, CaseIterable, Identifiable {
    case liveCommerce
    case podcastIntro
    case keynoteSpeech
    case productLaunch
    case interview
    case tutorial
    case custom

    var id: String { rawValue }

    var label: String {
        switch self {
        case .liveCommerce:    return "Live Commerce"
        case .podcastIntro:    return "Podcast Intro"
        case .keynoteSpeech:   return "Keynote Speech"
        case .productLaunch:   return "Product Launch"
        case .interview:       return "Interview"
        case .tutorial:        return "Tutorial"
        case .custom:          return "Custom"
        }
    }

    var icon: String {
        switch self {
        case .liveCommerce:    return "cart.fill"
        case .podcastIntro:    return "mic.fill"
        case .keynoteSpeech:   return "person.wave.2.fill"
        case .productLaunch:   return "sparkles"
        case .interview:       return "bubble.left.and.bubble.right.fill"
        case .tutorial:        return "play.rectangle.fill"
        case .custom:          return "wand.and.stars"
        }
    }

    var description: String {
        switch self {
        case .liveCommerce:
            return "Script for live-streaming product sales with call-to-actions and urgency."
        case .podcastIntro:
            return "Engaging opening segment for a podcast episode with hooks and transitions."
        case .keynoteSpeech:
            return "Structured speech with opening, key points, stories, and closing."
        case .productLaunch:
            return "Dramatic reveal script with problem → solution → demo → CTA flow."
        case .interview:
            return "Interview questions and follow-up prompts for a structured conversation."
        case .tutorial:
            return "Step-by-step instructional script with clear explanations and transitions."
        case .custom:
            return "Describe any scenario and the AI will generate a tailored script."
        }
    }

    var systemPrompt: String {
        let base = """
You are an expert scriptwriter for on-camera presenters, streamers, and speakers.
Write natural, conversational scripts that feel spontaneous when spoken aloud.
Use short sentences. Include natural pauses marked as [pause].
Include stage directions in brackets like [smile], [nod], [gesture], [look at camera].
Avoid overly formal language. Write like a real person talks.
Keep paragraphs short (1-3 sentences) for easy reading on a teleprompter.
"""
        switch self {
        case .liveCommerce:
            return base + """
You are writing a live commerce script. Create an energetic, persuasive script that:
- Opens with a strong hook to grab attention
- Highlights product benefits with specific details
- Creates urgency with limited-time offers
- Includes clear call-to-action phrases
- Uses conversational, hype-but-authentic tone
- Marks emphasis moments with [emphasis]
"""
        case .podcastIntro:
            return base + """
You are writing a podcast intro script. Create an engaging opening that:
- Hooks the listener in the first 10 seconds
- Introduces the episode topic clearly
- Mentions the guest if applicable
- Teases what's coming without giving everything away
- Sets the tone (casual, professional, humorous, etc.)
- Includes smooth transition to the main content
"""
        case .keynoteSpeech:
            return base + """
You are writing a keynote speech. Create a compelling presentation that:
- Opens with a story, question, or surprising fact
- Has 3-5 clear key points with supporting evidence
- Uses personal anecdotes and relatable examples
- Includes audience engagement moments [audience interaction]
- Builds to a memorable closing with a call to action
- Keeps tone inspiring but grounded
"""
        case .productLaunch:
            return base + """
You are writing a product launch script. Create a dramatic reveal that:
- Opens by painting the problem/pain point vividly
- Builds anticipation before the reveal [build tension]
- Introduces the product as the solution
- Walks through key features with benefits
- Includes a live demo walkthrough moment [demo]
- Closes with pricing, availability, and strong CTA
"""
        case .interview:
            return base + """
You are writing an interview guide. Create a structured interview that:
- Starts with warm-up questions to build rapport
- Progresses from easy to more challenging questions
- Includes follow-up prompts for deeper answers
- Has transition phrases between topics
- Ends with a strong closing question
- Mark the host's parts and leave gaps for guest responses
"""
        case .tutorial:
            return base + """
You are writing a tutorial script. Create a clear, step-by-step guide that:
- States the learning outcome upfront
- Breaks complex steps into simple chunks
- Explains the "why" not just the "how"
- Includes troubleshooting tips where relevant
- Uses encouraging language to keep viewers engaged
- Ends with a recap and next steps
"""
        case .custom:
            return base + """
Write a script tailored to the user's specific scenario and requirements.
Adapt tone, structure, and style based on the context provided.
"""
        }
    }

    var placeholderText: String {
        switch self {
        case .liveCommerce:
            return "Product: wireless earbuds, Price: $79, Offer: Buy 2 get 1 free, Audience: tech-savvy millennials"
        case .podcastIntro:
            return "Podcast: Tech Tomorrow, Episode: AI in healthcare, Guest: Dr. Sarah Chen, Tone: curious and optimistic"
        case .keynoteSpeech:
            return "Topic: The future of remote work, Audience: 500 CEOs, Duration: 20 min, Key message: Flexibility drives innovation"
        case .productLaunch:
            return "Product: Smart garden app, Problem: People kill houseplants, Key feature: AI watering reminders, Price: $9.99/mo"
        case .interview:
            return "Guest: Startup founder who failed 3 times before success, Theme: resilience, Duration: 45 min podcast"
        case .tutorial:
            return "Topic: How to edit photos in Lightroom, Level: beginner, Goal: edit a portrait in 10 minutes"
        case .custom:
            return "Describe your scenario in detail..."
        }
    }
}
