# Natural Language Java Library
java_import "simplenlg.lexicon.Lexicon"
java_import "simplenlg.framework.NLGFactory"
java_import "simplenlg.realiser.english.Realiser"
java_import 'simplenlg.features.Feature'
java_import 'simplenlg.features.NumberAgreement'
java_import 'simplenlg.features.Tense'

class NaturalLanguage
  attr_accessor :realiser, :word

  def initialize(opts = {})
    @@lexicon ||= Lexicon.getDefaultLexicon()
    @@nlgFactory ||= NLGFactory.new(@@lexicon)
    self.realiser = Realiser.new(@@lexicon)
    self.word = opts[:word]
  end

  def to_hash
    {
      :past => {
        :singular => past(self.word, true),
        :plural => past(self.word, false)
      },
      :present => {
        :singular => present(self.word, true),
        :plural => present(self.word, false)
      },
      :future => {
        :singular => future(self.word, true),
        :plural => future(self.word, false)
      },
      :pluralization => {
        :singular => singular(self.word),
        :plural => plural(self.word)
      }
    }
  end

  def past(word, singular = true)
    return unless word
    singular = singular ? NumberAgreement::SINGULAR : NumberAgreement::PLURAL
    v = @@nlgFactory.createClause()
    v.setVerb(word)
    v.setFeature(Feature::TENSE, Tense::PAST)
    v.setFeature(Feature::NUMBER, singular)
    self.realiser.realise(v).getRealisation()
  end

  def present(word, singular = true)
    return unless word
    singular = singular ? NumberAgreement::SINGULAR : NumberAgreement::PLURAL
    v = @@nlgFactory.createClause()
    v.setVerb(word)
    v.setFeature(Feature::TENSE, Tense::PRESENT)
    v.setFeature(Feature::PROGRESSIVE, true)
    v.setFeature(Feature::NUMBER, singular)
    Realiser.new(@@lexicon).realise(v).getRealisation()
  end

  def future(word, singular = true)
    singular = singular ? NumberAgreement::SINGULAR : NumberAgreement::PLURAL
    v = @@nlgFactory.createClause()
    v.setVerb(word)
    v.setFeature(Feature::TENSE, Tense::FUTURE)
    v.setFeature(Feature::PROGRESSIVE, true)
    v.setFeature(Feature::NUMBER, singular)
    Realiser.new(@@lexicon).realise(v).getRealisation()
  end

  def singular(word)
    return unless word
    v = @@nlgFactory.createClause()
    v.setVerb(word)
    v.setFeature(Feature::TENSE, Tense::PRESENT)
    v.setFeature(Feature::NUMBER, NumberAgreement::PLURAL)
    Realiser.new(@@lexicon).realise(v).getRealisation()
  end

  def plural(word)
    return unless word
    v = @@nlgFactory.createClause()
    v.setVerb(word)
    v.setFeature(Feature::TENSE, Tense::PRESENT)
    v.setFeature(Feature::NUMBER, NumberAgreement::SINGULAR)
    Realiser.new(@@lexicon).realise(v).getRealisation()
  end
end
