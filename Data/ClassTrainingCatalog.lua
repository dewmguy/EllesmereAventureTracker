-------------------------------------------------------------------------------
-- Static WoW: Forever class-trainer catalog.
--
-- The class tables loaded after this file are adapted from What's Training?
-- by fusionpit, commit 59763c2105428ccf99926919824c23d850bfbaa4.
-- That project is distributed under the MIT License; see THIRD_PARTY_NOTICES.md.
-------------------------------------------------------------------------------
local _, ns = ...

ns.ClassTrainingData = ns.ClassTrainingData or {}

function ns.forClass(classToken)
    ns.ClassTrainingData[classToken] = ns.ClassTrainingData[classToken] or {}
    return ns.ClassTrainingData[classToken]
end

ns.ClassTrainingCatalog = {
    source = "What's Training?",
    sourceURL = "https://github.com/fusionpit/WhatsTraining",
    sourceCommit = "59763c2105428ccf99926919824c23d850bfbaa4",
    license = "MIT",
}
