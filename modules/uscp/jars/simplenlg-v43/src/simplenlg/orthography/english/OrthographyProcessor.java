/*
 * The contents of this file are subject to the Mozilla Public License
 * Version 1.1 (the "License"); you may not use this file except in
 * compliance with the License. You may obtain a copy of the License at
 * http://www.mozilla.org/MPL/
 *
 * Software distributed under the License is distributed on an "AS IS"
 * basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See the
 * License for the specific language governing rights and limitations
 * under the License.
 *
 * The Original Code is "Simplenlg".
 *
 * The Initial Developer of the Original Code is Ehud Reiter, Albert Gatt and Dave Westwater.
 * Portions created by Ehud Reiter, Albert Gatt and Dave Westwater are Copyright (C) 2010-11 The University of Aberdeen. All Rights Reserved.
 *
 * Contributor(s): Ehud Reiter, Albert Gatt, Dave Wewstwater, Roman Kutlak, Margaret Mitchell.
 */
package simplenlg.orthography.english;

import java.util.ArrayList;
import java.util.List;

import simplenlg.features.DiscourseFunction;
import simplenlg.features.InternalFeature;
import simplenlg.framework.CoordinatedPhraseElement;
import simplenlg.framework.DocumentCategory;
import simplenlg.framework.DocumentElement;
import simplenlg.framework.ElementCategory;
import simplenlg.framework.ListElement;
import simplenlg.framework.NLGElement;
import simplenlg.framework.NLGModule;
import simplenlg.framework.StringElement;

/**
 * <p>
 * This processing module deals with punctuation when applied to
 * <code>DocumentElement</code>s. The punctuation currently handled by this
 * processor includes the following (as of version 4.0):
 * <ul>
 * <li>Capitalisation of the first letter in sentences.</li>
 * <li>Termination of sentences with a period if not interrogative.</li>
 * <li>Termination of sentences with a question mark if they are interrogative.</li>
 * <li>Replacement of multiple conjunctions with a comma. For example,
 * <em>John and Peter and Simon</em> becomes <em>John, Peter and Simon</em>.</li>
 * </ul>
 * </p>
 * 
 * 
 * @author D. Westwater, University of Aberdeen.
 * @version 4.0
 * 
 */
public class OrthographyProcessor extends NLGModule {

	@Override
	public void initialise() {
		// No initialisation.
	}

	@Override
	public NLGElement realise(NLGElement element) {
		NLGElement realisedElement = null;

		if (element != null) {
			ElementCategory category = element.getCategory();

			if (category instanceof DocumentCategory
					&& element instanceof DocumentElement) {
				List<NLGElement> components = ((DocumentElement) element)
						.getComponents();

				switch ((DocumentCategory) category) {

				case SENTENCE:
					realisedElement = realiseSentence(components, element);
					break;

				case LIST_ITEM:
					if (components != null && components.size() > 0) {
						// recursively realise whatever's in the list item
						// NB: this will realise embedded lists within list
						// items
						realisedElement = new ListElement(realise(components));
					}
					break;

				default:
					((DocumentElement) element)
							.setComponents(realise(components));
					realisedElement = element;
				}

			} else if (element instanceof ListElement) {
				// AG: changes here: if we have a premodifier, then we ask the
				// realiseList method to separate with a comma.
				StringBuffer buffer = new StringBuffer();
				List<NLGElement> children = element.getChildren();
				Object function = children.isEmpty() ? null : children.get(0)
						.getFeature(InternalFeature.DISCOURSE_FUNCTION);

				if (DiscourseFunction.PRE_MODIFIER.equals(function)) {
					realiseList(buffer, element.getChildren(), ",");
				} else {
					realiseList(buffer, element.getChildren(), "");
				}

				// realiseList(buffer, element.getChildren(), "");
				realisedElement = new StringElement(buffer.toString());

			} else if (element instanceof CoordinatedPhraseElement) {
				realisedElement = realiseCoordinatedPhrase(element
						.getChildren());

			} else {
				realisedElement = element;
			}

			// make the realised element inherit the original category
			// essential if list items are to be properly formatted later
			if (realisedElement != null) {
				realisedElement.setCategory(category);
			}
		}

		return realisedElement;
	}

	/**
	 * Performs the realisation on a sentence. This includes adding the
	 * terminator and capitalising the first letter.
	 * 
	 * @param components
	 *            the <code>List</code> of <code>NLGElement</code>s representing
	 *            the components that make up the sentence.
	 * @param element
	 *            the <code>NLGElement</code> representing the sentence.
	 * @return the realised element as an <code>NLGElement</code>.
	 */
	private NLGElement realiseSentence(List<NLGElement> components,
			NLGElement element) {

		NLGElement realisedElement = null;
		if (components != null && components.size() > 0) {
			StringBuffer realisation = new StringBuffer();
			realiseList(realisation, components, "");

			capitaliseFirstLetter(realisation);
			terminateSentence(realisation, element.getFeatureAsBoolean(
					InternalFeature.INTERROGATIVE).booleanValue());

			((DocumentElement) element).clearComponents();
			// realisation.append(' ');
			element.setRealisation(realisation.toString());
			realisedElement = element;
		}
		return realisedElement;
	}

	/**
	 * Adds the sentence terminator to the sentence. This is a period ('.') for
	 * normal sentences or a question mark ('?') for interrogatives.
	 * 
	 * @param realisation
	 *            the <code>StringBuffer<code> containing the current 
	 * realisation of the sentence.
	 * @param interrogative
	 *            a <code>boolean</code> flag showing <code>true</code> if the
	 *            sentence is an interrogative, <code>false</code> otherwise.
	 */
	private void terminateSentence(StringBuffer realisation,
			boolean interrogative) {
		char character = realisation.charAt(realisation.length() - 2);
		if (character != '.' && character != '?') {
			if (interrogative) {
				realisation.append('?');
			} else {
				realisation.append('.');
			}
		}
	}

	/**
	 * Capitalises the first character of a sentence if it is a lower case
	 * letter.
	 * 
	 * @param realisation
	 *            the <code>StringBuffer<code> containing the current 
	 * realisation of the sentence.
	 */
	private void capitaliseFirstLetter(StringBuffer realisation) {
		char character = realisation.charAt(0);
		if (character >= 'a' && character <= 'z') {
			character = (char) ('A' + (character - 'a'));
			realisation.setCharAt(0, character);
		}
	}

	@Override
	public List<NLGElement> realise(List<NLGElement> elements) {
		List<NLGElement> realisedList = new ArrayList<NLGElement>();

		if (elements != null && elements.size() > 0) {
			for (NLGElement eachElement : elements) {
				if (eachElement instanceof DocumentElement) {
					realisedList.add(realise(eachElement));
				} else {
					realisedList.add(eachElement);
				}
			}
		}
		return realisedList;
	}

	/**
	 * Realises a list of elements appending the result to the on-going
	 * realisation.
	 * 
	 * @param realisation
	 *            the <code>StringBuffer<code> containing the current 
	 * 			  realisation of the sentence.
	 * @param components
	 *            the <code>List</code> of <code>NLGElement</code>s representing
	 *            the components that make up the sentence.
	 * @param listSeparator
	 *            the string to use to separate elements of the list, empty if
	 *            no separator needed
	 */
	private void realiseList(StringBuffer realisation,
			List<NLGElement> components, String listSeparator) {

		NLGElement realisedChild = null;

		for (int i = 0; i < components.size(); i++) {
			NLGElement thisElement = components.get(i);
			realisedChild = realise(thisElement);
			String childRealisation = realisedChild.getRealisation();

			// check that the child realisation is non-empty
			if (childRealisation != null && childRealisation.length() > 0
					&& !childRealisation.matches("^[\\s\\n]+$")) {
				realisation.append(realisedChild.getRealisation());

				if (components.size() > 1 && i < components.size() - 1) {
					realisation.append(listSeparator);
				}

				realisation.append(' ');
			}
		}

		if (realisation.length() > 0) {
			realisation.setLength(realisation.length() - 1);
		}
	}

	/**
	 * Realises coordinated phrases. Where there are more than two coordinates,
	 * then a comma replaces the conjunction word between all the coordinates
	 * save the last two. For example, <em>John and Peter and Simon</em> becomes
	 * <em>John, Peter and Simon</em>.
	 * 
	 * @param components
	 *            the <code>List</code> of <code>NLGElement</code>s representing
	 *            the components that make up the sentence.
	 * @return the realised element as an <code>NLGElement</code>.
	 */
	private NLGElement realiseCoordinatedPhrase(List<NLGElement> components) {
		StringBuffer realisation = new StringBuffer();
		NLGElement realisedChild = null;

		int length = components.size();

		for (int index = 0; index < length; index++) {
			realisedChild = components.get(index);
			if (index < length - 2
					&& DiscourseFunction.CONJUNCTION.equals(realisedChild
							.getFeature(InternalFeature.DISCOURSE_FUNCTION))) {

				realisation.append(", "); //$NON-NLS-1$
			} else {
				realisedChild = realise(realisedChild);
				realisation.append(realisedChild.getRealisation()).append(' ');
			}
		}
		realisation.setLength(realisation.length() - 1);
		return new StringElement(realisation.toString().replace(" ,", ",")); //$NON-NLS-1$ //$NON-NLS-2$
	}
}
