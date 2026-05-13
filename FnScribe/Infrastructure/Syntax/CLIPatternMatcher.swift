//
//  CLIPatternMatcher.swift
//  FnScribe
//
//  Created by Artem Batutin on 2026-01-27.
//

import Foundation

/// Matches and transforms spoken CLI command patterns into proper CLI syntax
struct CLIPatternMatcher {
    
    /// Represents a CLI pattern mapping from spoken form to written form
    struct CLIPattern {
        let spoken: String
        let written: String
        let category: Category
        
        enum Category: String, CaseIterable {
            case git
            case npm
            case docker
            case general
            case symbols
        }
        
        init(spoken: String, written: String, category: Category = .general) {
            self.spoken = spoken.lowercased()
            self.written = written
            self.category = category
        }
    }
    
    // MARK: - Pattern Database
    
    /// Common CLI patterns organized by category
    static let patterns: [CLIPattern] = [
        // Git commands
        CLIPattern(spoken: "git commit dash m", written: "git commit -m", category: .git),
        CLIPattern(spoken: "git commit dash a dash m", written: "git commit -am", category: .git),
        CLIPattern(spoken: "git push origin", written: "git push origin", category: .git),
        CLIPattern(spoken: "git pull origin", written: "git pull origin", category: .git),
        CLIPattern(spoken: "git checkout dash b", written: "git checkout -b", category: .git),
        CLIPattern(spoken: "git checkout", written: "git checkout", category: .git),
        CLIPattern(spoken: "git branch dash d", written: "git branch -d", category: .git),
        CLIPattern(spoken: "git branch dash capital d", written: "git branch -D", category: .git),
        CLIPattern(spoken: "git stash pop", written: "git stash pop", category: .git),
        CLIPattern(spoken: "git stash", written: "git stash", category: .git),
        CLIPattern(spoken: "git merge", written: "git merge", category: .git),
        CLIPattern(spoken: "git rebase dash i", written: "git rebase -i", category: .git),
        CLIPattern(spoken: "git rebase", written: "git rebase", category: .git),
        CLIPattern(spoken: "git log dash n", written: "git log -n", category: .git),
        CLIPattern(spoken: "git diff", written: "git diff", category: .git),
        CLIPattern(spoken: "git status", written: "git status", category: .git),
        CLIPattern(spoken: "git add dot", written: "git add .", category: .git),
        CLIPattern(spoken: "git add", written: "git add", category: .git),
        CLIPattern(spoken: "git reset dash dash hard", written: "git reset --hard", category: .git),
        CLIPattern(spoken: "git reset", written: "git reset", category: .git),
        CLIPattern(spoken: "git clone", written: "git clone", category: .git),
        CLIPattern(spoken: "git init", written: "git init", category: .git),
        CLIPattern(spoken: "git remote add origin", written: "git remote add origin", category: .git),
        
        // npm/yarn/pnpm commands
        CLIPattern(spoken: "npm install", written: "npm install", category: .npm),
        CLIPattern(spoken: "npm i", written: "npm i", category: .npm),
        CLIPattern(spoken: "npm run dev", written: "npm run dev", category: .npm),
        CLIPattern(spoken: "npm run build", written: "npm run build", category: .npm),
        CLIPattern(spoken: "npm run start", written: "npm run start", category: .npm),
        CLIPattern(spoken: "npm run test", written: "npm run test", category: .npm),
        CLIPattern(spoken: "npm install dash d", written: "npm install -D", category: .npm),
        CLIPattern(spoken: "npm install dash dash save dev", written: "npm install --save-dev", category: .npm),
        CLIPattern(spoken: "npm uninstall", written: "npm uninstall", category: .npm),
        CLIPattern(spoken: "yarn add", written: "yarn add", category: .npm),
        CLIPattern(spoken: "yarn add dash d", written: "yarn add -D", category: .npm),
        CLIPattern(spoken: "yarn dev", written: "yarn dev", category: .npm),
        CLIPattern(spoken: "yarn build", written: "yarn build", category: .npm),
        CLIPattern(spoken: "yarn start", written: "yarn start", category: .npm),
        CLIPattern(spoken: "pnpm install", written: "pnpm install", category: .npm),
        CLIPattern(spoken: "pnpm add", written: "pnpm add", category: .npm),
        CLIPattern(spoken: "pnpm dev", written: "pnpm dev", category: .npm),
        CLIPattern(spoken: "npx", written: "npx", category: .npm),
        
        // Docker commands
        CLIPattern(spoken: "docker build dash t", written: "docker build -t", category: .docker),
        CLIPattern(spoken: "docker run dash it", written: "docker run -it", category: .docker),
        CLIPattern(spoken: "docker run dash d", written: "docker run -d", category: .docker),
        CLIPattern(spoken: "docker run dash p", written: "docker run -p", category: .docker),
        CLIPattern(spoken: "docker compose up", written: "docker compose up", category: .docker),
        CLIPattern(spoken: "docker compose up dash d", written: "docker compose up -d", category: .docker),
        CLIPattern(spoken: "docker compose down", written: "docker compose down", category: .docker),
        CLIPattern(spoken: "docker ps", written: "docker ps", category: .docker),
        CLIPattern(spoken: "docker ps dash a", written: "docker ps -a", category: .docker),
        CLIPattern(spoken: "docker exec dash it", written: "docker exec -it", category: .docker),
        CLIPattern(spoken: "docker logs dash f", written: "docker logs -f", category: .docker),
        CLIPattern(spoken: "docker stop", written: "docker stop", category: .docker),
        CLIPattern(spoken: "docker rm", written: "docker rm", category: .docker),
        CLIPattern(spoken: "docker rmi", written: "docker rmi", category: .docker),
        CLIPattern(spoken: "docker pull", written: "docker pull", category: .docker),
        CLIPattern(spoken: "docker push", written: "docker push", category: .docker),
        
        // General CLI patterns
        CLIPattern(spoken: "cd dot dot", written: "cd ..", category: .general),
        CLIPattern(spoken: "cd", written: "cd", category: .general),
        CLIPattern(spoken: "ls dash la", written: "ls -la", category: .general),
        CLIPattern(spoken: "ls dash l", written: "ls -l", category: .general),
        CLIPattern(spoken: "ls dash a", written: "ls -a", category: .general),
        CLIPattern(spoken: "ls", written: "ls", category: .general),
        CLIPattern(spoken: "mkdir dash p", written: "mkdir -p", category: .general),
        CLIPattern(spoken: "mkdir", written: "mkdir", category: .general),
        CLIPattern(spoken: "rm dash rf", written: "rm -rf", category: .general),
        CLIPattern(spoken: "rm dash r", written: "rm -r", category: .general),
        CLIPattern(spoken: "rm", written: "rm", category: .general),
        CLIPattern(spoken: "cp dash r", written: "cp -r", category: .general),
        CLIPattern(spoken: "cp", written: "cp", category: .general),
        CLIPattern(spoken: "mv", written: "mv", category: .general),
        CLIPattern(spoken: "cat", written: "cat", category: .general),
        CLIPattern(spoken: "grep dash r", written: "grep -r", category: .general),
        CLIPattern(spoken: "grep dash i", written: "grep -i", category: .general),
        CLIPattern(spoken: "grep", written: "grep", category: .general),
        CLIPattern(spoken: "curl dash x", written: "curl -X", category: .general),
        CLIPattern(spoken: "curl", written: "curl", category: .general),
        CLIPattern(spoken: "chmod", written: "chmod", category: .general),
        CLIPattern(spoken: "chown", written: "chown", category: .general),
        CLIPattern(spoken: "sudo", written: "sudo", category: .general),
        CLIPattern(spoken: "which", written: "which", category: .general),
        CLIPattern(spoken: "echo", written: "echo", category: .general),
        CLIPattern(spoken: "export", written: "export", category: .general),
        CLIPattern(spoken: "source", written: "source", category: .general),
        CLIPattern(spoken: "tail dash f", written: "tail -f", category: .general),
        CLIPattern(spoken: "head dash n", written: "head -n", category: .general),
        CLIPattern(spoken: "kill dash 9", written: "kill -9", category: .general),
        CLIPattern(spoken: "ps aux", written: "ps aux", category: .general),
        
        // Symbol patterns (processed in order, longer patterns first)
        CLIPattern(spoken: "dash dash", written: "--", category: .symbols),
        CLIPattern(spoken: "double dash", written: "--", category: .symbols),
        CLIPattern(spoken: "dash", written: "-", category: .symbols),
        CLIPattern(spoken: "pipe", written: "|", category: .symbols),
        CLIPattern(spoken: "greater than greater than", written: ">>", category: .symbols),
        CLIPattern(spoken: "greater than", written: ">", category: .symbols),
        CLIPattern(spoken: "less than", written: "<", category: .symbols),
        CLIPattern(spoken: "ampersand ampersand", written: "&&", category: .symbols),
        CLIPattern(spoken: "double ampersand", written: "&&", category: .symbols),
        CLIPattern(spoken: "ampersand", written: "&", category: .symbols),
        CLIPattern(spoken: "semicolon", written: ";", category: .symbols),
        CLIPattern(spoken: "tilde", written: "~", category: .symbols),
        CLIPattern(spoken: "dot slash", written: "./", category: .symbols),
        CLIPattern(spoken: "dot dot slash", written: "../", category: .symbols),
        CLIPattern(spoken: "slash", written: "/", category: .symbols),
        CLIPattern(spoken: "backslash", written: "\\", category: .symbols),
        CLIPattern(spoken: "asterisk", written: "*", category: .symbols),
        CLIPattern(spoken: "star", written: "*", category: .symbols),
        CLIPattern(spoken: "question mark", written: "?", category: .symbols),
        CLIPattern(spoken: "at sign", written: "@", category: .symbols),
        CLIPattern(spoken: "hash", written: "#", category: .symbols),
        CLIPattern(spoken: "dollar sign", written: "$", category: .symbols),
        CLIPattern(spoken: "percent", written: "%", category: .symbols),
        CLIPattern(spoken: "caret", written: "^", category: .symbols),
        CLIPattern(spoken: "equals", written: "=", category: .symbols),
        CLIPattern(spoken: "plus", written: "+", category: .symbols),
        CLIPattern(spoken: "colon", written: ":", category: .symbols),
        CLIPattern(spoken: "dot", written: ".", category: .symbols),
        CLIPattern(spoken: "comma", written: ",", category: .symbols),
        CLIPattern(spoken: "underscore", written: "_", category: .symbols),
    ]
    
    /// Patterns sorted by spoken length (longest first) for greedy matching
    private static let sortedPatterns: [CLIPattern] = {
        patterns.sorted { $0.spoken.count > $1.spoken.count }
    }()
    
    // MARK: - Pattern Matching
    
    /// Matches and replaces CLI patterns in the given text
    /// - Parameter text: The input text with spoken CLI commands
    /// - Returns: Text with CLI patterns replaced with proper syntax
    static func match(_ text: String) -> String {
        var result = text.lowercased()
        
        // Apply patterns in order (longest first to avoid partial matches)
        for pattern in sortedPatterns {
            result = result.replacingOccurrences(
                of: pattern.spoken,
                with: pattern.written,
                options: .caseInsensitive
            )
        }
        
        return result
    }
    
    /// Matches CLI patterns with word boundary awareness
    /// - Parameter text: The input text
    /// - Returns: Text with CLI patterns replaced
    static func matchWithBoundaries(_ text: String) -> String {
        var result = text
        
        for pattern in sortedPatterns {
            // Create regex pattern with word boundaries
            let regexPattern = "\\b\(NSRegularExpression.escapedPattern(for: pattern.spoken))\\b"
            if let regex = try? NSRegularExpression(pattern: regexPattern, options: .caseInsensitive) {
                result = regex.stringByReplacingMatches(
                    in: result,
                    options: [],
                    range: NSRange(result.startIndex..., in: result),
                    withTemplate: pattern.written
                )
            }
        }
        
        return result
    }
    
    /// Gets patterns for a specific category
    /// - Parameter category: The category to filter by
    /// - Returns: Array of patterns in that category
    static func patterns(for category: CLIPattern.Category) -> [CLIPattern] {
        patterns.filter { $0.category == category }
    }
    
    /// Checks if text contains any CLI patterns
    /// - Parameter text: The text to check
    /// - Returns: True if CLI patterns are detected
    static func containsCLIPatterns(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        return patterns.contains { lowercased.contains($0.spoken) }
    }
}
